class TankVolume < ActiveRecord::Base
  def self.xxx(first_date, last_date)
    raise "#{last_date.to_s} is before #{first_date.to_s}" if last_date <= first_date
    first_week = Week.where(:date => first_date).first
    raise "No match for #{first_date.to_s}" if first_week.nil?
    last_week = Week.where(:date => last_date).first
    raise "No match for #{last_date.to_s}" if last_week.nil?
    date_range = first_date+1.day..last_date
    deliveries = FuelDelivery.where(:delivery_date => date_range)
    #dispenser_sales = DispenserSale
  end
end
