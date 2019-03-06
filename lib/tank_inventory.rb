class TankInventory < HashManager
  def initialize
    hash = {}
    FuelDelivery::GRADES.each do |grade|
      hash[grade] = {:amount => 0.0, :gallons => 0.0, :per_gallon => 0.0, :deliveries => []}
    end
    super(hash)
  end

  def self.create(week)
    instance = self.new
    dispenser_net = DispenserSalesTotal.net_sales_for_period(week.previous_week, week, false)
    tank_volume = week.tank_volume
    fuel_delivery = week.fuel_deliveries.order(:delivery_date).last
    FuelDelivery::GRADES.each do |grade|
      gallons = dispenser_net.send(grade).gallons
      offset = tank_volume[grade]
      grade_instance = instance.send(grade)
      grade_instance.deliveries = fuel_delivery.get_descending_deliveries(grade, gallons, offset)
      grade_instance.gallons = gallons.round(2)
      per_gallon = 0.0
      grade_instance.deliveries.each do |delivery|
        per_gallon += delivery.per_gallon * delivery.applied_gallons / gallons
      end
      grade_instance.per_gallon = (per_gallon + 0.01).round(4)
      grade_instance.amount = (gallons * grade_instance.per_gallon).round(2)
    end
    return instance
  end

  def self.value_of_inventory(week)
    fuel_delivery = week.fuel_deliveries.order(:delivery_date).last
    tank_volume = week.tank_volume
    instance = self.new
    FuelDelivery::GRADES.each do |grade|
      gallons = tank_volume[grade]
      offset = 0
      grade_instance = instance.public_send(grade)
      grade_instance.deliveries = fuel_delivery.get_descending_deliveries(grade, gallons, offset)
      grade_instance.gallons = gallons
      grade_instance.deliveries.each do |delivery|
        grade_instance.per_gallon += (delivery.per_gallon * delivery.applied_gallons / gallons)
      end
      grade_instance.per_gallon += 0.01
      grade_instance.amount = gallons * grade_instance.per_gallon
    end
    return instance
  end

  def gallons
    return self.regular.gallons + self.premium.gallons + self.diesel.gallons
  end
  def amount
    return self.regular.amount + self.premium.amount + self.diesel.amount
  end
  def per_gallon
    return self.amount / self.gallons
  end

  def calculated_versus_actual
    last_week = self.week
    first_week = last_week.previous_week
    self.calculated_versus_actual_report(first_week, last_week)
  end

  def self.calculated_versus_actual_report(first_week, last_week)
    net_sales = DispenserSalesTotal.net_sales_for_period(first_week, last_week)
    grades = ['regular', 'premium', 'diesel']
    hash = grades.inject({}) {|hash,grade|
      hash[grade] = net_sales.sales_total_first_week.send(grade); hash}
    unblended_first_week = HashManager.new(hash)
    hash = grades.inject({}) {|hash,grade|
      hash[grade] = net_sales.sales_total_last_week.send(grade); hash}
    unblended_last_week = HashManager.new(hash)

    blended_grades = ['regular', 'plus', 'premium', 'diesel']
    blended_first_week = DispenserSalesTotal.new(first_week, true)
    blended_last_week = DispenserSalesTotal.new(last_week, true)

    net_hash = blended_grades.inject({}) {
      |hash,grade| hash[grade] = (blended_last_week.send(grade).gallons -
      blended_first_week.send(grade).gallons).round(2);hash}
    net_blended =  HashManager.new(net_hash)

    weeks = Week.where("date > ? and date <= ?", first_week.date, last_week.date)
    fuel_deliveries = FuelDelivery.where(:week_id => weeks.map(&:id))
    #fuel_deliveries = last_week.fuel_deliveries
    fuel_hash = grades.inject({}) {|hash, grade|
      hash[grade] = fuel_deliveries.map{|d| d[grade + "_gallons"].to_f}.sum;hash}
    fuel_deliveries_total = HashManager.new(fuel_hash)

    calculated_hash = grades.inject({}) {|hash,grade| hash[grade] =
      first_week.tank_volume.send(grade).to_f + fuel_deliveries_total.send(grade) -
      net_sales.send(grade).gallons; hash}
    calculated_volume = HashManager.new(calculated_hash)

    difference_hash = grades.inject({}) {|hash,grade|
      hash[grade] = last_week.tank_volume.send(grade).to_f - calculated_volume.send(grade); hash}
    difference_volume = HashManager.new(difference_hash)

    return net_blended
  end

  class Gallons < HashManager

    attr_accessor   :first_week
    attr_accessor   :last_week

    def initialize(first_week, last_week)
      @first_week = first_week
      @last_week = last_week
      begin_volume = first_week.previous_week.tank_volume.as_json.
        select{|key, value| FuelDelivery::GRADES.include?(key)}
      end_volume = last_week.tank_volume.as_json.
        select{|key, value| FuelDelivery::GRADES.include?(key)}
      @fuel_grades = FuelDelivery::GRADES.inject({}) {|hash,grade| hash[grade] = 0.0;hash}
      @dispenser_grades = DispenserSale::GRADES.inject({}) {|hash,grade| hash[grade] = 0.0;hash}

      gallons_hash = {'tank' => {'begin' => begin_volume, 'end' => end_volume},
        'sold' => {'first' => {'fuel' => @fuel_grades.dup, 'dispenser' => @dispenser_grades.dup},
        'last' => {'fuel' => @fuel_grades.dup, 'dispenser' => @dispenser_grades.dup},
        'net' => {'fuel' => @fuel_grades.dup, 'dispenser' => @dispenser_grades.dup}},
        'deliveries' => []}

      super(gallons_hash)
    end

    def self.create(first_week, last_week)
      instance = self.new(first_week, last_week)
      instance.build
      return instance
    end

    def build
      fuel_stats =  DispenserSalesTotal.net_sales_for_period(first_week.previous_week, last_week)
      FuelDelivery::GRADES.each do |grade|
        self["sold.first.fuel.#{grade}"] = fuel_stats.sales_total_first_week["#{grade}.gallons"]
        self["sold.first.fuel.#{grade}"] = fuel_stats.sales_total_first_week["#{grade}.gallons"]
        self["sold.net.fuel.#{grade}"] = fuel_stats["#{grade}.gallons"]
      end
      dispenser_stats =  DispenserSalesTotal.net_sales_for_period(first_week.previous_week, last_week, true)
      DispenserSale::GRADES.each do |grade|
        self["sold.first.dispenser.#{grade}"] = dispenser_stats.sales_total_first_week["#{grade}.gallons"]
        self["sold.first.dispenser.#{grade}"] = dispenser_stats.sales_total_first_week["#{grade}.gallons"]
        self["sold.net.dispenser.#{grade}"] = dispenser_stats["#{grade}.gallons"]
      end
      fuel_deliveries = FuelDelivery.where(:week_id => [first_week.id..last_week.id])
      fuel_deliveries.each do |fuel_delivery|
        hash = {'date' => fuel_delivery.delivery_date, 'invoice_number' => fuel_delivery.invoice_number}
        hash['regular'] = fuel_delivery.regular_gallons.to_f
        hash['premium'] = fuel_delivery.premium_gallons.to_f
        hash['diesel'] = fuel_delivery.diesel_gallons.to_f
        self.deliveries << HashManager.new(hash)
      end
    end

    def calculated_volume
      volume = @fuel_grades.dup
      total_deliveries = self.deliveries_total
      volume.keys.each do |grade|
        volume[grade] = self["tank.begin.#{grade}"] + total_deliveries[grade] -
          self["sold.net.fuel.#{grade}"]
      end
      HashManager.new(volume)
    end

    def difference
      calculated = self.calculated_volume
      HashManager.new(@fuel_grades.keys.inject(@fuel_grades.dup) {|hash,grade|
        hash[grade] = self["tank.end.#{grade}"] - calculated[grade];hash})
    end

    def deliveries_total
      HashManager.new(@fuel_grades.keys.inject(@fuel_grades.dup) {|hash,grade|
        hash[grade] = self.deliveries.map{|d| d[grade]}.sum; hash})
    end

  end
end
