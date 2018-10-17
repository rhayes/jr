class FuelProfit
  def self.year_to_date(tax_year=2018)
    all_weeks = Week.tax_year(tax_year).order(:date)
    weeks = all_weeks.select{|week| !week.dispenser_sales.empty?}.sort_by{|week| week.date}
    first_week = weeks.first
    last_week = weeks.last
    first_tank_volume = first_week.previous_week.tank_volume
    last_tank_volume = last_week.tank_volume
    fuel_deliveries = weeks.flat_map{|week| week.fuel_deliveries}
    fuel_cost = fuel_deliveries.map{|delivery| delivery.total}.sum
    commissions = Transaction.tax_year(2018).fuel_commission
    total_commissions = commissions.map{|transaction| transaction.amount}.sum
    net_sales = DispenserSalesTotal.net_sales_for_period(first_week.previous_week, last_week)
    total_sales = net_sales.total_sales
    total_gallons = net_sales.total_gallons
    months = (last_week.date.year - first_week.date.year) * 12 +
      last_week.date.month - first_week.date.month -
      (last_week.date.day >= first_week.date.day ? 0 : 1) + 1
    rent = Money.new(90000 * months)
    net_profit = total_sales - fuel_cost - total_commissions

    return HashManager.new({:net_profit => net_profit,
      :per_gallon => net_profit.to_f / total_gallons,
      :gallons => total_gallons, :retail => total_sales,
      :cost => fuel_cost + total_commissions,
      :difference_gallons => {:regular => last_tank_volume.regular - first_tank_volume.regular,
        :premium => last_tank_volume.premium - first_tank_volume.premium,
        :diesel => last_tank_volume.diesel - first_tank_volume.diesel}})
  end
end
