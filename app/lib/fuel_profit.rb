class FuelProfit

  attr_accessor   :net_sales
  attr_accessor   :fuel_detail
  attr_accessor   :grade_profit

  def self.create_weekly_report(week)
    report = FuelProfit.new
    report.build_weekly_report(week)
    report
  end

  def build_weekly_report(week)
    self.net_sales = DispenserPeriodNet.create(week, week)
    self.fuel_detail = FuelDeliveryDetail.for_week_sales(week)
    self.grade_profit = GradeProfit.create(net_sales, fuel_detail)
  end

  def self.create_summary_annual_report(weeks)
    report = FuelProfit.new
    #net_sales = DispenserSale.net_for_range_of_weeks(week, week)
    report.build_summary_annual_report(weeks)
    report
  end
=begin
  def self.create_report_for_weeks(first_week_id, last_week_id)
    reports = []
    raise "beginning week is after ending week" if first_week_id > last_week_id
    for week_id in first_week_id .. last_week_id
      report = FuelProfit.new
      week = Week.find(week_id)
      report.net_sales = DispenserSale.net_for_week(week)
      report.fuel_detail = FuelDeliveryDetail.for_week_sales(week)
      report.grade_profit = GradeProfit.create(report.net_sales, report.fuel_detail)
      reports << report
    end
    reports
  end
=end
  def build_summary_annual_report(weeks)
    #weeks = Week.tax_year(tax_year).order(:id)
    self.net_sales = DispenserPeriodNet.create(weeks.first, weeks.last)
    self.fuel_detail = FuelDeliveryDetail.for_range_of_weeks_sales(weeks.first, weeks.last)
    self.grade_profit = GradeProfit.create(net_sales, fuel_detail)
  end

  def self.net_fuel_profit_for_week(week)
    self.net_fuel_profit([week])
  end

  def self.net_fuel_profit_for_year(tax_year = 2019)
    weeks = Week.tax_year(tax_year).order(:id)
    self.net_fuel_profit(weeks)
  end

  def self.net_fuel_profit(weeks)
    #weeks = Week.tax_year(tax_year).order(:id)
    week_ids = weeks.map(&:id)
    commissions = Transaction.fuel_commission.where(:week_id => week_ids)
    commission = commissions.map{|c| c.amount.to_f.round(2)}.sum
    net_sales = DispenserSale.net_for_range_of_weeks(weeks.first, weeks.last)
    deposits = Transaction.fuel_sale.where(:week_id => week_ids)
    fuel_sales = (deposits.map{|d| d.amount.to_f}.sum - 900.0 * deposits.select{|d| d.includes_lease}.count).round(2)
    fuel_deliveries = FuelDelivery.where(:week => week_ids)
    fuel_cost = fuel_deliveries.map{|d| d.total.to_f}.sum.round(2)
    fuel_costs = Transaction.fuel_cost.where(:week_id => week_ids)
    fuel_cost = fuel_costs.map{|c| c.amount.to_f.round(2)}.sum
    beginning_inventory = weeks.first.previous_week.value_of_inventory.amount.round(2)
    ending_inventory = weeks.last.value_of_inventory.amount.round(2)
    {:net => fuel_sales - commission - fuel_cost + ending_inventory - beginning_inventory,
      :fuel_sales => fuel_sales, :commission => commission, :fuel_cost => fuel_cost,
      :ending_inventory => ending_inventory, :beginning_inventory => beginning_inventory}
  end

  class GradeProfit < HashManager
    def initialize
      grades = FuelDelivery::GRADES + ['total']
      hash = grades.inject({:entries => []}) {|h,grade| h.merge!({grade.to_sym => nil}); h}
      super(hash)
    end

    def self.create(net_sales, fuel_detail)
      grade_profit = self.new
      total_gallons = 0
      total_retail = total_cost = 0.0
      FuelDelivery::GRADES.each do |grade|
        total_gallons += (gallons = fuel_detail[grade].gallons) ##################
        total_retail += (retail = net_sales.dollars[grade])
        cost_per_gallon = fuel_detail[grade].average_per_gallon + 0.07
        total_cost += fuel_detail[grade].average_per_gallon * fuel_detail[grade].gallons  #########
        grade_profit.entries << GradeProfitEntry.create(grade, gallons, retail, cost_per_gallon)
        grade_profit[grade] = grade_profit.entries.last
      end
      overall_cost_per_gallon = total_cost / total_gallons + 0.07
      grade_profit.entries << GradeProfitEntry.create('total', total_gallons, total_retail, overall_cost_per_gallon)
      grade_profit.total = grade_profit.entries.last
      grade_profit
    end

    def add_entry(grade, gallons, retail, cost_per_gallon)
      entry = GradeProfitEntry.create(grade, gallons, retail, cost_per_gallon)
    end

    def get_entry(name)
      entries.select{|entry| entry.description == name}.first
    end
  end

  class GradeProfitEntry < HashManager
    def initialize(description)
      super({:description => description, :gallons => nil, :retail => nil,
        :cost_per_gallon => nil, :cost => nil, :net => nil, :retail_per_gallon => nil,
        :net_per_gallon => nil})
    end

    def self.create(description, gallons, retail, cost_per_gallon)
      profit = GradeProfitEntry.new(description)
      profit.gallons = gallons
      profit.retail = retail
      profit.cost_per_gallon = cost_per_gallon
      profit.cost = profit.cost_per_gallon * profit.gallons
      profit.net = profit.retail - profit.cost
      profit.retail_per_gallon = profit.retail / profit.gallons
      profit.net_per_gallon = profit.net / profit.gallons
      profit
    end

  end

end
