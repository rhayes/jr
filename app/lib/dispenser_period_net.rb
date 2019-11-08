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
      total = 0.0
      DispenserSale::GRADES.each do |grade|
        net_value = (ending_week_total[amount_type][grade] -
          previous_week_total[amount_type][grade]).round(2)
        self[amount_type].merge({grade => net_value})
        total += net_value
      end
      self[amount_type].merge({'total' => total})
      unless blended
        self[amount_type].regular = (self[amount_type].regular + 0.65 * self[amount_type].plus).round(2)
        self[amount_type].premium = (self[amount_type].premium + 0.35 * self[amount_type].plus).round(2)
        self[amount_type].plus = nil
      end
    end

    week_ids = Week.where("id > ? and id < ?", beginning_week.id, ending_week.id).pluck(:id)
    return if week_ids.empty?
    dispenser_sales = DispenserSale.where(:week_id => week_ids)

    DispenserSale::GRADES.each do |grade|
      gallons_adjustment = dispenser_sales.map{|w| w.send(grade + "_gallons_adjustment")}.sum
      dollars_adjustment = dispenser_sales.map{|w| w.send(grade + "_dollars_adjustment")}.sum
      if blended || grade != 'plus'
        self.gallons[grade] += gallons_adjustment
        self.dollars[grade] += dollars_adjustment
      else
        self.gallons.regular += 0.65 * gallons_adjustment
        self.dollars.regular += 0.65 * dollars_adjustment
        self.gallons.premium += 0.35 * gallons_adjustment
        self.dollars.premium += 0.35 * dollars_adjustment
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
