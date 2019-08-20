class DispenserWeekSummary < HashManager
  def self.create(week)
    instance = self.new({})
    instance.build(week)
    return instance
  end

  def build(week)
    dispensers = week.dispenser_sales.order(:number)
    dispensers.each do |dispenser|
      dispenser_number = 'dispenser_' + dispenser.number.to_s
      self.merge(init_dispenser_hash(dispenser_number))
      ['dollars','gallons'].each do |amount_type|
        DispenserSale::GRADES.each do |grade|
          database_column = (amount_type == 'dollars') ? grade + "_cents" : grade + "_gallons"
          amount = dispenser.send(database_column).to_f
          amount = amount / 100.0 if amount_type == 'dollars'
          self[dispenser_number][amount_type][grade].amount = amount
          offset = DispenserOffset.dispenser(dispenser.number).grade_type(database_column).
            where("start_date <= ?", week.date).order(:start_date).last.offset.to_f
          self[dispenser_number][amount_type][grade].offset = offset
          adjustment = dispenser.send(database_column + "_adjustment")
          self[dispenser_number][amount_type][grade].adjustment = adjustment
          self[dispenser_number][amount_type][grade].total = amount + offset + adjustment
        end
      end
    end
  end

  def total
    totals = initial_total
    _columns.each do |dispenser|
      totals._columns.each do |amount_type|
        DispenserSale::GRADES.each do |grade|
          totals[amount_type][grade] += self[dispenser][amount_type][grade].amount
        end
      end
    end
    return totals
  end

  def adjusted_total
    totals = initial_total
    _columns.each do |dispenser|
      totals._columns.each do |amount_type|
        DispenserSale::GRADES.each do |grade|
          totals[amount_type][grade] += self[dispenser][amount_type][grade].total
        end
      end
    end
    return rounded(totals)
  end

  def totals_array(adjusted = true, interleaved = true)
    array = []
    dollars_gallons_order = ['dollars','gallons']
    totals = adjusted ? self.adjusted_total : self.total
    DispenserSale::GRADES.each do |grade|
      dollars_gallons_order.each {|type| array << totals[type][grade]}
    end
    array
  end

  def net_amounts_week

  end

  private

  def initial_total
    hash = {'dollars' => {}, 'gallons' => {}}
    hash.keys.each do |amount_type|
      DispenserSale::GRADES.each {|grade| hash[amount_type].merge!({grade => 0.0})}
    end
    return HashManager.new(hash)
  end

  def rounded(totals)
    totals._columns.each do |amount_type|
      DispenserSale::GRADES.each {|grade| totals[amount_type][grade] = totals[amount_type][grade].round(2)}
    end
    totals
  end

  def init_dispenser_hash(dispenser_number)
    dispenser_hash = {dispenser_number => {}}
    ['dollars','gallons'].each do |amount_type|
      amount_type_hash = {amount_type => {}}
      DispenserSale::GRADES.each do |grade|
        amount_type_hash[amount_type][grade] = {'amount' => 0.0, 'offset' => 0.0,
          'adjustment' => 0.0, 'total' => 0.0}
      end
      dispenser_hash[dispenser_number].merge!(amount_type_hash)
    end
    return dispenser_hash
  end

end
