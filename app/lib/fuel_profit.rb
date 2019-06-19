class FuelProfit

  attr_accessor   :net_sales
  attr_accessor   :fuel_detail
  attr_accessor   :grade_profit

  def self.create_report_for_week(week)
    report = FuelProfit.new
    report.build_report_for_week(week)
    report
  end

  def build_report_for_week(week)
    self.net_sales = DispenserSale.net_for_week(week)
    self.fuel_detail = FuelDeliveryDetail.for_week_sales(week)
    self.grade_profit = GrossProfit.create(net_sales, fuel_detail)
  end

  def self.create_grade_details_year_to_date_report(tax_year = 2019)
    report = FuelProfit.new
    #net_sales = DispenserSale.net_for_range_of_weeks(week, week)
    report.build_grade_details_year_to_date_report(tax_year)
    report
  end

  def self.create_report_for_weeks(first_week_id, last_week_id)
    reports = []
    raise "beginning week is after ending week" if first_week_id > last_week_id
    for week_id in first_week_id .. last_week_id
      report = FuelProfit.new
      week = Week.find(week_id)
      report.net_sales = DispenserSale.net_for_week(week)
      report.fuel_detail = FuelDeliveryDetail.for_week_sales(week)
      report.grade_profit = GrossProfit.create(report.net_sales, report.fuel_detail)
      reports << report
    end
    reports
  end

  def build_grade_details_year_to_date_report(tax_year = 2019)
    weeks = Week.tax_year(tax_year).order(:id)
    self.net_sales = DispenserSale.net_for_range_of_weeks(weeks.first, weeks.last)
    self.fuel_detail = FuelDeliveryDetail.for_range_of_weeks_sales(weeks.first, weeks.last)
    self.grade_profit = GrossProfit.create(net_sales, fuel_detail)
  end

  def build_report_for_weeks(first_week_id, last_week_id)
    collection = []
    raise "beginning week is after ending week" if first_week_id > last_week_id
    for week_id in first_week_id .. last_week_id
      week = Week.find(week_id)
      self.net_sales = DispenserSale.net_for_week(week)
      self.fuel_detail = FuelDeliveryDetail.for_week_sales(week)
      self.grade_profit = GrossProfit.create(net_sales, fuel_detail)
    end
  end

  class GrossProfit < HashManager
    def initialize
      super({:entries => []})
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
      end
      overall_cost_per_gallon = total_cost / total_gallons + 0.07
      grade_profit.entries << GradeProfitEntry.create('total', total_gallons, total_retail, overall_cost_per_gallon)
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
      super({:description => description, :gallons => nil, :retail => nil, :cost_per_gallon => nil})
    end

    def self.create(description, gallons, retail, cost_per_gallon)
      profit = GradeProfitEntry.new(description)
      profit.gallons = gallons
      profit.retail = retail
      profit.cost_per_gallon = cost_per_gallon
      profit
    end

    def cost
      self.cost_per_gallon * self.gallons
    end

    def net
      self.retail - self.cost
    end

    def retail_per_gallon
      self.retail / self.gallons
    end

    def net_per_gallon
      self.net / self.gallons
    end
  end

end
