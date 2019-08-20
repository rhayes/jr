class DispenserPeriodNet < HashManager
  def self.create(first_week, last_week, blended = false)
    instance = self.new({'dollars' => {}, 'gallons' => {}})
    instance.build(first_week, last_week, blended)
    instance
  end

  def build(beginning_week, ending_week, blended = false)
    previous_week = beginning_week.previous_week
    previous_week_total = DispenserWeekSummary.create(previous_week).adjusted_total
    ending_week_total = DispenserWeekSummary.create(ending_week).adjusted_total
    self._columns.each do |amount_type|
      DispenserSale::GRADES.each do |grade|
        net_value = (ending_week_total[amount_type][grade] -
          previous_week_total[amount_type][grade]).round(2)
        self[amount_type].merge({grade => net_value})
      end
      unless blended
        self[amount_type].regular = (self[amount_type].regular + 0.65 * self[amount_type].plus).round(2)
        self[amount_type].premium = (self[amount_type].premium + 0.35 * self[amount_type].plus).round(2)
        self[amount_type].plus = nil
      end
    end
  end

  def totals_array(interleaved = true)
    array = []
    dollars_gallons_order = ['dollars','gallons']
    DispenserSale::GRADES.each do |grade|
      dollars_gallons_order.each {|type| array << self[type][grade]}
    end
    array
  end

  def total_gallons
    gallons.regular + gallons.plus.to_f + gallons.premium + gallons.diesel
  end

  def total_dollars
    dollars.regular + dollars.plus.to_f + dollars.premium + dollars.diesel
  end
end
