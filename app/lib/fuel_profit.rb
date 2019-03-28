class FuelProfit
  def self.weekly_report(week)
    report = FuelProfit.new
    report.create_weekly_report(week)
    report
  end

  def create_weekly_report(week)
    #previous_week = week.previous_week
    fuel_deliveries = week.fuel_deliveries
    ending_tank_volume = week.tank_volume
  end

  def create_report(first_week, last_week)
  end

  def self.gather_fuel_deliveries(week, grade, total_gallons, offset=0)
    gallons_column = grade + "_gallons"
    fuel_deliveries = FuelDelivery.where("delivery_date <= ?",week.date).
      where("#{gallons_column} > 0").order("delivery_date desc").limit(20)
    deliveries = []
    total_offset_remaining = offset.to_f
    total_gallons_remaining = total_gallons.to_f
    fuel_deliveries.each do |fuel_delivery|
      gallons = fuel_delivery[gallons_column].to_f
      offset_applied = total_offset_remaining <= gallons ? total_offset_remaining : gallons
      total_offset_remaining -= offset_applied
      gallons_available = gallons - offset_applied
      gallons_applied = gallons_available > total_gallons_remaining ?
        total_gallons_remaining : gallons_available
      total_gallons_remaining -= gallons_applied
      per_gallon = fuel_delivery[grade + "_per_gallon"].to_f
      deliveries << HashManager.new({'id' => fuel_delivery.id,
        'date' => fuel_delivery.delivery_date, 'invoice_number' => fuel_delivery.invoice_number,
        'per_gallon' => per_gallon, 'offset_applied' => offset_applied,
        'gallons_applied' => gallons_applied, 'gallons' => gallons})
      break if total_gallons_remaining <= 0.9
    end
    average_per_gallon = (deliveries.inject(0.0) {|total,d| total += d.per_gallon * d.gallons_applied; total} / total_gallons).to_f.round(4)
    return average_per_gallon, deliveries
  end
end
