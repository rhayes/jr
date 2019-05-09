class FuelDeliveryDetail < HashManager

  attr_accessor   :ending_date

  def initialize(ending_date)
    @ending_date = ending_date
    super({})
  end

  def self.for_week_sales(week)
    net_sales = DispenserSale.net_for_range_of_weeks(week, week)
    array = []
    FuelDelivery::GRADES.each do |grade|
      offset = week.tank_volume[grade]
      gallons = net_sales.gallons[grade]
      array << HashManager.new({:grade => grade, :gallons => gallons, :offset => offset})
    end
    self.create(week.date, array)
  end

  def self.for_week_inventory(week)
    array = []
    FuelDelivery::GRADES.each do |grade|
      total_gallons = week.tank_volume[grade]
      array << HashManager.new({:grade => grade, :total_gallons => total_gallons, :offset => 0})
    end
    self.create(week.date, array)
  end

  def self.create(ending_date, array)
    info = self.new(ending_date)
    info.build(array)
    info
  end

  def build(array)
    array.each do |grade_info|
      delivery_info = FuelDelivered.create(grade_info.grade, ending_date, grade_info.gallons, grade_info.offset)
      self.merge({grade_info.grade => delivery_info})
    end
  end

  def value_of
    FuelDelivery::GRADES.inject(0.0) {|value,grade| value += self[grade].value_of; value}
  end

  class FuelDelivered < HashManager
    def initialize(grade, ending_date, gallons, offset)
      super({:grade => grade, :ending_date => ending_date,
        :gallons => gallons, :offset => offset, :deliveries => []})
    end
    def self.create(grade, ending_date, gallons, offset)
      results = FuelDelivered.new(grade, ending_date, gallons, offset)
      results.build
    end
    def build
      gallons_column = grade + "_gallons"
      fuel_deliveries = FuelDelivery.where("delivery_date <= ?",ending_date).
        where("#{gallons_column} > 0").order("delivery_date desc").limit(20)
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
