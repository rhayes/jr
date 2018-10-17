class TankVolume < ActiveRecord::Base

  belongs_to    :week

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

  def total
    return regular + premium + diesel
  end

  def value_in_tanks
    grades = ['regular','premium','diesel']
    value_hash = {}
    week = self.week
    (grades + ['total']).each do |key|
      value_hash[key] = {:amount => nil, :gallons => self.public_send(key), :per_gallon => 0.0}
    end
    results = HashManager.new(value_hash)
    total_object = results.total
    grades.each do |grade|
      if grade == 'premium'
        gallons_column = "supreme_gallons"
        per_gallon_column = "supreme_per_gallon"
      else
        gallons_column = grade + "_gallons"
        per_gallon_column = grade + "_per_gallon"
      end
      grade_object = results.public_send(grade)
      fuel_deliveries = FuelDelivery.where("delivery_date <= ?",week.date).
        where("#{gallons_column} > 0").order("delivery_date desc")
      total_gallons = self[grade]
      accumulated_gallons = 0.0
      per_gallon = 0.9
      fuel_deliveries.each do |fuel_delivery|
        per_gallon = fuel_delivery[per_gallon_column].to_f
        gallons = fuel_delivery[gallons_column].to_f
        if accumulated_gallons + gallons >= total_gallons
          applied_gallons = total_gallons - accumulated_gallons
        else
          applied_gallons = gallons
        end
        grade_object.per_gallon += (per_gallon * (applied_gallons / total_gallons)).to_f
        grade_object.amount = (grade_object.per_gallon * grade_object.gallons).to_f
      end
    end
    return results
  end
end
