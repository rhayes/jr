class FuelDeliveryDetail < HashManager

  attr_accessor   :beginning_date
  attr_accessor   :ending_date

  def initialize(beginning_date, ending_date)
    @beginning_date = beginning_date
    @ending_date = ending_date
    super({})
  end

  def self.for_week_sales(week)
    net_sales = DispenserPeriodNet.create(week, week)
    array = []
    FuelDelivery::GRADES.each do |grade|
      offset = week.tank_volume[grade]
      gallons = net_sales.gallons[grade]
      array << HashManager.new({:grade => grade, :gallons => gallons, :offset => offset})
    end
    self.create(week.previous_week.date - 2.months, week.date, array)
  end

  def self.for_range_of_weeks_sales(beginning_week, ending_week)
    net_sales = DispenserPeriodNet.create(beginning_week, ending_week)
    array = []
    FuelDelivery::GRADES.each do |grade|
      offset = ending_week.tank_volume[grade]
      gallons = net_sales.gallons[grade]
      array << HashManager.new({:grade => grade, :gallons => gallons, :offset => offset})
    end
    self.create(beginning_week.date - 2.months, ending_week.date, array)
  end

  def self.for_week_inventory(week)
    array = []
    FuelDelivery::GRADES.each do |grade|
      total_gallons = week.tank_volume[grade]
      array << HashManager.new({:grade => grade, :total_gallons => total_gallons, :offset => 0})
    end
    self.create(week.date, array)
  end

  def self.create(beginning_date, ending_date, array)
    info = self.new(beginning_date, ending_date)
    info.build(array)
    info
  end

  def build(array)
    array.each do |grade_info|
      delivery_info = FuelDelivered.create(grade_info.grade, beginning_date,
        ending_date, grade_info.gallons, grade_info.offset)
      self.merge({grade_info.grade => delivery_info})
    end
    regular_gallons = self.regular.deliveries.map(&:gallons).sum
    premium_gallons = self.premium.deliveries.map(&:gallons).sum
    diesel_gallons = self.diesel.deliveries.map(&:gallons).sum
    total_gallons = regular_gallons + premium_gallons + diesel_gallons
    self.merge({:summary => {:regular => regular_gallons, :premium => premium_gallons,
      :diesel => diesel_gallons, :total => total_gallons}})
  end

  def value_of
    FuelDelivery::GRADES.inject(0.0) {|value,grade| value += self[grade].value_of; value}
  end

  class FuelDelivered < HashManager
    def initialize(grade, beginning_date, ending_date, gallons, offset)
      super({:grade => grade, :beginning_date => beginning_date, :ending_date => ending_date,
        :gallons => gallons, :offset => offset, :deliveries => []})
    end
    def self.create(grade, beginning_date, ending_date, gallons, offset)
      results = FuelDelivered.new(grade, beginning_date, ending_date, gallons, offset)
      results.build
    end
    def build
      gallons_column = grade + "_gallons"
      date_range = beginning_date..ending_date
      #fuel_deliveries = FuelDelivery.where("delivery_date <= ?",ending_date).
      #  where("#{gallons_column} > 0").order("delivery_date desc").limit(20)
      fuel_deliveries = FuelDelivery.where(:delivery_date => date_range).
        where("#{gallons_column} > 0").order("delivery_date desc")
      deliveries = []
      total_offset_remaining = offset.to_f
      total_gallons_remaining = gallons.to_f
      fuel_deliveries.each do |fuel_delivery|
        gallons = fuel_delivery[gallons_column].to_f
        offset_applied = total_offset_remaining <= gallons ? total_offset_remaining : gallons
        total_offset_remaining -= offset_applied
        gallons_available = gallons - offset_applied
        gallons_applied = gallons_available > total_gallons_remaining ?
          total_gallons_remaining : gallons_available
        total_gallons_remaining -= gallons_applied
        per_gallon = fuel_delivery[grade + "_per_gallon"].to_f
        self.deliveries << HashManager.new({'id' => fuel_delivery.id,
          'date' => fuel_delivery.delivery_date, 'invoice_number' => fuel_delivery.invoice_number,
          'per_gallon' => per_gallon, 'offset_applied' => offset_applied,
          'gallons_applied' => gallons_applied, 'gallons' => gallons})
        break if total_gallons_remaining <= 0.9
      end
      return self
    end
    def average_per_gallon
      (deliveries.inject(0.0) {|total,d| total += d.per_gallon * d.gallons_applied; total} / self.gallons).to_f.round(4)
    end
    def value_of
      self.average_per_gallon * self.gallons
    end
  end

end
