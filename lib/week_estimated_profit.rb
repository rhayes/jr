class WeekEstimatedProfit < HashManager

  attr_accessor   :week
  attr_accessor   :grade_totals
  attr_accessor   :profit

  FUEL_GRADES = ['regular', 'supreme', 'diesel']

  def initialize(week)
    @week = week
    hash = {}
    FUEL_GRADES.each do |fuel_grade|
      aliass = fuel_grade == 'supreme' ? 'premium' : fuel_grade
      grade_info = {'alias' => aliass, 'gallons' => 0.0, 'per_gallon' => 0.0, 'deliveries' => []}
      hash[fuel_grade] = grade_info
      grade_hash = {}
      (FUEL_GRADES + ['total']).each do |grade|
        grade_hash[grade] = {'gallons_sold' => 0, 'estimated_per_gallon' => 0.0,
          'retail' => Money.new(0), 'cost' => Money.new(0), 'net' => 0.0}
      end
      @profit = HashManager.new(grade_hash)
    end
    super(hash)
  end

  def self.create(week)
    instance = self.new(week)
    instance.grade_totals = instance.build
    return instance
  end

  def build
    net_sales = DispenserSalesTotal.net_sales_for_period(week.previous_week, week)
    grade_totals = GradeTotal.new(self.week, net_sales)
    grade_totals.build_grades
    total_profit_row = self.profit.total
    FUEL_GRADES.each do |grade|
      grade_profit_row = self.profit.public_send(grade)
      grade_totals_row = grade_totals.retrieve_by_grade(grade)

      grade_profit_row.gallons_sold = grade_totals_row.gallons_sold
      total_profit_row.gallons_sold += grade_profit_row.gallons_sold

      grade_profit_row.estimated_per_gallon = grade_totals_row.estimated_per_gallon.round(4)

      grade_profit_row.retail = grade_totals_row.amount
      total_profit_row.retail += grade_profit_row.retail

      cost = grade_profit_row.estimated_per_gallon * grade_profit_row.gallons_sold
      grade_profit_row.cost = Money.new(100 * cost)
      total_profit_row.cost += grade_profit_row.cost

      grade_profit_row.net = grade_profit_row.retail - grade_profit_row.cost
      total_profit_row.net += grade_profit_row.net
    end
    total_profit_row.estimated_per_gallon =
      (total_profit_row.cost.to_f / total_profit_row.gallons_sold).round(4)
    return grade_totals
  end

  class GradeTotal < HashManager

    attr_accessor   :week
    attr_accessor   :net_profit

    def initialize(week, net_sales)
      @week = week
      plus_amount_half = net_sales.plus.amount / 2.0
      plus_gallons_half = net_sales.plus.gallons / 2.0
      regular_hash = {'name' => 'regular', 'amount' => net_sales.regular.amount + plus_amount_half,
        'estimated_per_gallon' => 0.0, 'gallons_sold' => (net_sales.regular.gallons +
        plus_gallons_half).round(2).to_i, 'net_profit' => 0.0, 'deliveries' => []}
      premium_hash = {'name' => 'supreme', 'amount' => net_sales.premium.amount + plus_amount_half,
        'estimated_per_gallon' => 0.0, 'gallons_sold' => (net_sales.premium.gallons +
        plus_gallons_half).round(2).to_i, 'net_profit' => 0.0, 'deliveries' => []}
      diesel_hash = {'name' => 'diesel', 'amount' => net_sales.diesel.amount,
        'estimated_per_gallon' => 0.0, 'gallons_sold' => net_sales.diesel.gallons.round(2).to_i,
        'net_profit' => 0.0, 'deliveries' => []}
      hash = {'regular' => Grade.new('regular',regular_hash),
        'premium' => Grade.new('premium',premium_hash),
        'diesel' => Grade.new('diesel',diesel_hash),}
      super(hash)
    end

    def retrieve_by_grade(grade)
      grade_rows = self.to_hash.keys.map{|key| self.public_send(key)}
      return grade_rows.select{|grade_row| grade_row.name == grade}.first
    end

    def delivery_gallons_column(grade)
      return self.public_send(grade).delivery_gallons_column
    end

    def delivery_per_gallon_column(grade)
      return self.public_send(grade).delivery_per_gallon_column
    end

    def build_grades
      grades = ['regular', 'premium', 'diesel']
      grades.each {|grade| self.public_send(grade).build(self.week)}
      self.net_profit = grades.inject(0.0) {|total, grade|
        total += self.public_send(grade).net_profit; total}
    end

    class Grade < HashManager

      attr_accessor   :grade

      def initialize(grade, hash)
        @grade = grade
        super(hash)
      end

      def delivered_gallons_column
        return self.name + "_gallons"
      end

      def delivered_per_gallon_column
        return self.name + "_per_gallon"
      end

      def build(week)
        fuel_deliveries = FuelDelivery.where("delivery_date < ?",week.date).
          where("#{delivered_gallons_column} > 0").order("delivery_date desc")
        accumulated_gallons = 0
        fuel_deliveries.each_with_index do |fuel_delivery, index|
          delivered_gallons = fuel_delivery[delivered_gallons_column]
          if index == 0
            days = (week.date - fuel_delivery.delivery_date).to_i
            delivered_gallons = ((delivered_gallons / 7.0) * days).to_i if days < 7
          end
          accumulated_gallons += delivered_gallons
          self.deliveries << HashManager.new({'id' => fuel_delivery.id,
            'date' => fuel_delivery.delivery_date,
            'per_gallon' => fuel_delivery[delivered_per_gallon_column].to_f,
            'total_gallons' => fuel_delivery[delivered_gallons_column],
            'applied_gallons' => delivered_gallons})
          break if accumulated_gallons >= self.gallons_sold
        end
        self.deliveries.last.applied_gallons -= (accumulated_gallons - self.gallons_sold)
        self.estimated_per_gallon = (self.deliveries.inject(0.0) {|total,d|
          total += d.per_gallon * d.applied_gallons; total} / self.gallons_sold.to_f) + 0.07
        self.net_profit = self.amount.to_f - (self.estimated_per_gallon * self.gallons_sold)
      end

    end
  end

end
