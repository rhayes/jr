class YearLease < ActiveRecord::Base

  scope		:tax_year, lambda{|year| where(:id => year)}

  monetize 	:amount_cents, with_model_currency: :amount_currency

  def self.rent(year)
    return Money.new(90000 * Date.today.month) if year == Date.today.year
    return self.tax_year(year).first.amount
  end
end
