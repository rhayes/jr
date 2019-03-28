class DispenserSale < ActiveRecord::Base

  GRADES = ['regular', 'plus', 'premium', 'diesel']

  belongs_to    :week

  monetize 	:regular_cents, with_model_currency: :regular_currency
  monetize 	:plus_cents, with_model_currency: :plus_currency
  monetize 	:premium_cents, with_model_currency: :premium_currency
  monetize 	:diesel_cents, with_model_currency: :diesel_currency
=begin
  def self.dispenser_totals_for_week(week_id)
    entries = self.where(:week_id => week_id)
    dispensers = entries.map(&:number).uniq
    results = {'regular' => {}, 'plus' => {}, 'premium' => {}, 'diesel' => {}}
    dispensers.each do |dispenser|

    end
  end
=end

  def self.sales_by_grade(week_id)
    entries = self.where(:week_id => week_id)
    results = {}
    results['regular']['amount'] = entries.map{|e| e.regular}.sum
    results['regular']['gallons'] = entries.map{|e| e.regular_gallons}.sum
    return results
  end

  def self.confirm_week(tax_year = Date.today.year)
    array = []
    sales = DispenserSale.joins(:week).select("dispenser_sales.id, dispenser_sales.date, weeks.id as week_id")
    sales.each do |sale|
      week = sale.week
      array << DispenserSale.find(sale.id) unless week.date_range.include?(sale.date)
    end
    return array
  end

  def self.xxx(tax_year = Date.today.year)
    first_week = Week.tax_year(tax_year-1).order(:id).last
    weeks = Week.tax_year(tax_year).order("id desc")
    last_week = nil
    weeks.each do |week|
      unless week.dispenser_sales.empty?
        last_week = week
        break
      end
    end
    regular = last_week.regular - first_week.regular
    plus = last_week.plus - first_week.plus
    premium = last_week.premium - first_week.premium
    diesel = last_week.diesel - first_week.diesel
    total = regular + plus + premium + diesel
    return total, regular, plus, premium, diesel
  end

  def sales
    regular = self.dispenser_sales.map{|s| s.regular}.sum
    plus = self.dispenser_sales.map{|s| s.plus}.sum
    premium = self.dispenser_sales.map{|s| s.premium}.sum
    diesel = self.dispenser_sales.map{|s| s.diesel}.sum
    return regular, plus, premium, diesel
  end

  def regular_gallons
    return self.regular_volume.to_f
  end

  def regular_gallons_adjustment
    return self.regular_volume_adjustment.to_f
  end

  def plus_gallons
    return self.plus_volume.to_f
  end

  def plus_gallons_adjustment
    return self.plus_volume_adjustment.to_f
  end

  def premium_gallons
    return self.premium_volume.to_f
  end

  def premium_gallons_adjustment
    return self.premium_volume_adjustment.to_f
  end

  def diesel_gallons
    return self.diesel_volume.to_f
  end

  def diesel_gallons_adjustment
    return self.diesel_volume_adjustment.to_f
  end

  def self.week_report_data(week)
    data = DispenserReport.new({})
    dispensers = week.dispenser_sales.order(:number)
    dispensers.each do |dispenser|
      dispenser_number = 'dispenser_' + dispenser.number.to_s
      data.merge(self.init_dispenser_hash(dispenser, dispenser_number))
      ['dollars','gallons'].each do |amount_type|
        GRADES.each do |grade|
          database_column = (amount_type == 'dollars') ? grade + "_cents" : grade + "_gallons"
          amount = dispenser.send(database_column).to_f
          amount = amount / 100.0 if amount_type == 'dollars'
          data[dispenser_number][amount_type][grade].amount = amount
          offset = DispenserOffset.dispenser(dispenser.number).grade_type(database_column).
            where("start_date <= ?", week.date).order(:start_date).last.offset.to_f
          data[dispenser_number][amount_type][grade].offset = offset
          adjustment = dispenser.send(database_column + "_adjustment")
          data[dispenser_number][amount_type][grade].adjustment = adjustment
          data[dispenser_number][amount_type][grade].total = amount + offset + adjustment
        end
      end
    end
    return data
  end

  def self.init_dispenser_hash(dispenser, dispenser_number)
    dispenser_hash = {dispenser_number => {}}
    ['dollars','gallons'].each do |amount_type|
      amount_type_hash = {amount_type => {}}
      GRADES.each do |grade|
        amount_type_hash[amount_type][grade] = {'amount' => 0.0, 'offset' => 0.0,
          'adjustment' => 0.0, 'total' => 0.0}
      end
      dispenser_hash[dispenser_number].merge!(amount_type_hash)
    end
    return dispenser_hash
  end

  def self.net_for_range_of_weeks(beginning_week, ending_week, blended = false)
    previous_week = beginning_week.previous_week
    previous_week_total = self.week_report_data(previous_week).adjusted_total
    ending_week_total = self.week_report_data(ending_week).adjusted_total
    net = NetDispenserReport.new({'dollars' => {}, 'gallons' => {}})
    net._columns.each do |amount_type|
      GRADES.each do |grade|
        net_value = (ending_week_total[amount_type][grade] -
          previous_week_total[amount_type][grade]).round(2)
        net[amount_type].merge({grade => net_value})
      end
      unless blended
        net[amount_type].regular = (net[amount_type].regular + 0.65 * net[amount_type].plus).round(2)
        net[amount_type].premium = (net[amount_type].premium + 0.35 * net[amount_type].plus).round(2)
        net[amount_type].plus = nil
      end
    end
    net
  end

  def self.net_for_week(week, blended = false)
    DispenserSale.net_for_range_of_weeks(week, week, blended)
  end

  class NetDispenserReport < HashManager
    def totals_array(interleaved = true)
      array = []
      dollars_gallons_order = ['dollars','gallons']
      GRADES.each do |grade|
        dollars_gallons_order.each {|type| array << self[type][grade]}
      end
      array
    end
  end

  class DispenserReport < HashManager
    def total
      totals = initial_total
      _columns.each do |dispenser|
        totals._columns.each do |amount_type|
          GRADES.each do |grade|
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
          GRADES.each do |grade|
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
      GRADES.each do |grade|
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
        GRADES.each {|grade| hash[amount_type].merge!({grade => 0.0})}
      end
      return HashManager.new(hash)
    end

    def rounded(totals)
      totals._columns.each do |amount_type|
        GRADES.each {|grade| totals[amount_type][grade] = totals[amount_type][grade].round(2)}
      end
      totals
    end
  end

end
