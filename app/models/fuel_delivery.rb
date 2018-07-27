class FuelDelivery < ActiveRecord::Base

    belongs_to    :week
    belongs_to    :fuel_transaction, :class_name => 'Transaction',
      :foreign_key => 'transaction_id', :optional => true

    monetize 	:monthly_tank_charge_cents, with_model_currency: :monthly_tank_charge_currency

    def regular_total
      total = (self.regular_gallons * self.regular_per_gallon +
        self.regular_gallons * self.storage_tank_fee).round(2)
      return Money.new((100.0 * total).to_i)
    end

    def regular_total_without_tank_fee
      total = (self.regular_gallons * self.regular_per_gallon).round(2)
      return Money.new((100.0 * total).to_i)
    end

    def supreme_total
      total = (self.supreme_gallons * self.supreme_per_gallon +
        self.supreme_gallons * self.storage_tank_fee).round(2)
      return Money.new((100.0 * total).to_i)
    end

    def supreme_total_without_tank_fee
      total = (self.supreme_gallons * self.supreme_per_gallon).round(2)
      return Money.new((100.0 * total).to_i)
    end

    def diesel_total
      total = (self.diesel_gallons * self.diesel_per_gallon +
        self.diesel_gallons * self.storage_tank_fee).round(2)
      return Money.new((100.0 * total).to_i)
    end

    def diesel_total_without_tank_fee
      total = (self.diesel_gallons * self.diesel_per_gallon).round(2)
      return Money.new((100.0 * total).to_i)
    end

    def total
      return self.regular_total + self.supreme_total +
        self.diesel_total + self.monthly_tank_charge + Money.new(self.adjustment_cents)
    end

    def premium_per_gallon
      return self.supreme_per_gallon
    end

    def self.confirm_week(tax_year = Date.today.year)
      array = []
      deliveries = FuelDelivery.joins(:week).select("fuel_deliveries.id, fuel_deliveries.delivery_date, weeks.id as week_id")
      deliveries.each do |delivery|
        week = delivery.week
        array << FuelDelivery.find(delivery.id) unless week.date_range.include?(delivery.delivery_date)
      end
      return array
    end

    def self.match_with_transactions(year = Date.today.year)
      deliveries = FuelDelivery.where(:delivery_date => Date.new(year, 1, 1)..Date.new(year, 12, 31))
      array = []
      deliveries.each do |delivery|
        match = delivery.match_transaction
        array << delivery unless match
      end
      return array
    end

    def match_transaction
      dates = self.delivery_date..self.delivery_date+10.days
      transaction = Transaction.fuel_cost.
        where(:amount_cents => self.total.cents, :date => dates).first
      self.transaction_id = transaction.nil? ? nil : transaction.id
      self.save!
      return !self.transaction_id.nil?
    end
end
