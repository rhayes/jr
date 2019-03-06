class Deposit < ActiveRecord::Base
  belongs_to  :week
  #belongs_to  :transaction

  before_save   :enforce_relationship
  def check
    raise "Must select a week" if week_id.nil?
    raise "Must select a transaction" if transaction_id.nil?
    week = Week.find_by_id(week_id)
    return if week.nil?
    transaction = Transaction.find_by_id(transaction_id)
    return if transaction.nil?
  end

  def self.populate(weeks, rent_cents = 90000)
    no_matches = []
    weeks.each do |week|
      net_sales = DispenserSalesTotal.net_sales_for_period(week.previous_week, week)
      week_total_sales = net_sales.total_sales
      deposit_range = (week_total_sales.cents - 2)..(week_total_sales.cents + 2)
      deposits = Transaction.where("date > ?",week.date).fuel_sale.limit(2).order(:date)
      puts "Week:  #{week.id}  -- #{week.date.to_s}"
      match = false
      deposits.each do |deposit|
        range = Deposit.deposit_range(week_total_sales.cents)
        puts "\tDeposit:  #{deposit.id}  --  #{deposit.date.to_s}  -- #{deposit.amount.to_s}"
        for i in 0..1
          match = range.include?(deposit.amount.cents)
          puts "\t\t#{match}  --  Range:  #{range}"
          break if match
          range = Deposit.deposit_range(week_total_sales.cents + rent_cents)
        end
        break if match
      end
      no_matches << week.id unless match
    end
    puts "No Matches:  #{no_matches}"
    return no_matches
  end

  def self.deposit_range(amount_cents, cents = 2)
    (amount_cents - cents)..(amount_cents + cents)
  end
=begin
  def self.populate(weeks)
    weeks.each do |week|
      net_sales = DispenserSalesTotal.net_sales_for_period(week.previous_week, week)
      week_total_sales = net_sales.total_sales
      deposits = Transaction.where("date > ?",week.date).fuel_sale.limit(2).order(:date)
      rent = week.date.month != week.previous_week.date.month
      week_total_sales += Money.new(90000) if rent
      deposit_range = (week_total_sales.cents - 5)..(week_total_sales.cents + 5)
      deposit = deposits.select{|d| deposit_range.include?(d.amount.cents)}.first
      puts "Deposits:  #{deposits.count}  --  Range:  #{deposit_range}  --  Amount: #{deposits.first.amount_cents}  --  Rent:  #{rent}"
      transaction_id = deposit.nil? ? nil : deposit.id
      puts "\tWeek:  #{week.id}/#{week.date.to_date.to_s}  --  Transaction ID:  #{transaction_id}"
    end
  end
=end
end
