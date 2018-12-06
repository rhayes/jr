class TankInventory < HashManager
  def initialize
    hash = {}
    FuelDelivery::GRADES.each do |key|
      hash[key] = {:amount => 0.0, :gallons => 0.0, :per_gallon => 0.0, :deliveries => []}
    end
    super(hash)
  end

  def self.create(fuel_delivery, parameters)
    instance = self.new
    FuelDelivery::GRADES.each do |grade|
      gallons = parameters[grade]['gallons']
      offset = parameters[grade]['offset']
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

  def self.value_of_inventory(week)
    fuel_delivery = week.fuel_deliveries.order(:delivery_date).last
    tank_volume = week.tank_volume
    parameters = FuelDelivery::GRADES.inject({}) {|hash,grade|
      hash[grade] = {'gallons' => tank_volume[grade], 'offset' => 0};hash}
    puts "#{parameters}"
    return self.create(fuel_delivery, parameters)
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
end
