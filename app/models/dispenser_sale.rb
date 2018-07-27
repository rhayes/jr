class DispenserSale < ActiveRecord::Base

  belongs_to    :week

  monetize 	:regular_cents, with_model_currency: :regular_currency
  monetize 	:plus_cents, with_model_currency: :plus_currency
  monetize 	:premium_cents, with_model_currency: :premium_currency
  monetize 	:diesel_cents, with_model_currency: :diesel_currency

  def self.dispenser_totals_for_week(week_id)
    entries = self.where(:week_id => week_id)
    dispensers = entries.map(&:number).uniq
    results = {'regular' => {}, 'plus' => {}, 'premium' => {}, 'diesel' => {}}
    dispensers.each do |dispenser|

    end
  end

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
end
