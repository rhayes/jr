class WeekEstimatedProfit

  attr_accessor   :previous_week
  attr_accessor   :this_week

  def initialize(week)
    @this_week = week
    @previous_week = week.last_week
  end

  def self.build(week)
    report = WeekEstimatedProfit.new(week)
    return report.create
  end

  def create
    net_sales_hash = DispenserSalesTotal.net_sales_for_period(previous_week, this_week).to_hash
  end

  class EstimatedFuelCost < HashManager

    GRADES = ['regular', 'supreme', 'diesel']

    attr_accessor   :week

    def initialize(week)
      @week = week
      hash = {}
      GRADES.each do |grade|
        grade_info = {'weighted_cost' => 0.0, 'total_gallons' => 0, 'delivery_count' => 0}
        hash[grade] = grade_info
      end
      super(hash)
    end

    def self.build(week)
      instance = self.new(week)
      return instance
    end

    def create
      #GRADES.each do
    end
  end
end
