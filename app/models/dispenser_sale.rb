class DispenserSale < ActiveRecord::Base

  GRADES = ['regular', 'plus', 'premium', 'diesel']

  belongs_to    :week

  monetize 	:regular_cents, with_model_currency: :regular_currency
  monetize 	:plus_cents, with_model_currency: :plus_currency
  monetize 	:premium_cents, with_model_currency: :premium_currency
  monetize 	:diesel_cents, with_model_currency: :diesel_currency

  def self.sales_by_grade(week_id)
    entries = self.where(:week_id => week_id)
    results = {}
    results['regular']['amount'] = entries.map{|e| e.regular}.sum
    results['regular']['gallons'] = entries.map{|e| e.regular_gallons}.sum
    return results
  end

  def self.total_all(field = 'gallons')
    array = []
    if field == 'gallons'
      ['regular','plus','premium','diesel'].each do |grade|
        array << DispenserSale.pluck(grade + '_volume').map{|amount| amount.to_f}.sum.round(2)
      end
    elsif field == 'dollars'
      ['regular','plus','premium','diesel'].each do |grade|
        array << DispenserSale.all.map{|sale| sale.send(grade).to_f}.sum.round(2)
      end
    elsif field == 'gallons_adjustment'
      ['regular','plus','premium','diesel'].each do |grade|
        array << DispenserSale.all.map{|sale| sale.send(grade+"_"+field).to_f}.sum.round(2)
      end
    elsif field == 'dollars_adjustment'
      ['regular','plus','premium','diesel'].each do |grade|
        array << DispenserSale.all.map{|sale| sale.send(grade+"_"+field).to_f}.sum.round(2)
      end
    end
    array
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

  def regular_cents_adjustment
    return self.regular_dollars_adjustment.to_f
  end

  def plus_cents_adjustment
    return self.plus_dollars_adjustment.to_f
  end

  def premium_cents_adjustment
    return self.premium_dollars_adjustment.to_f
  end

  def diesel_cents_adjustment
    return self.diesel_dollars_adjustment.to_f
  end

  def self.week_report_data(week)
    DispenserReport.create(week)
  end

  def self.net_for_range_of_weeks(beginning_week, ending_week, blended = false)
    return NetDispenserReport.create(beginning_week, ending_week, blended)
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

  def self.to_hash_array
    self.all.as_json
  end

  def self.to_json_file
    json = JSON.pretty_generate(self.all.as_json)
    file = File.open(File.expand_path("~/Documents/dispensers.json"), 'w') {|file| file.write(json.force_encoding("UTF-8"))}
  end
end
