class Transaction < ActiveRecord::Base

  has_one   :fuel_delivery

  scope   :credit, -> {where(:type_of => 'credit')}
  scope   :debit, -> {where(:type_of => 'debit')}
  scope   :category_not_set, -> {where(:category => 'not_set', :tax_year => 2017..3017)}
  scope   :fuel_cost, -> {where(:category => 'fuel_cost')}
  scope   :fuel_sale, -> {where(:category => 'fuel_sale')}
  scope   :fuel_commission, -> {where(:category => 'fuel_commission')}
  scope   :rent, -> {where(:category => 'rent')}
  scope		:tax_year, lambda{|year| where(:tax_year => year)}
  scope		:category, lambda{|category| where(:category => category)}

  monetize 	:amount_cents, with_model_currency: :amount_currency
  monetize 	:balance_cents, with_model_currency: :balance_currency

  def self.csv_import(file_name, update = false, init = false)
    #if init
    #  self.delete_all
    #  sql = "ALTER TABLE `#{self.table_name}` AUTO_INCREMENT = 1"
    #  ActiveRecord::Base.connection.execute(sql)
    #end
    file_path = File.expand_path("~/Downloads/#{file_name}")
    csv = CSV.read(file_path)
    csv.shift
    hash_array = []
    csv.each do |row|
      description = row[4].nil? ? '' : row[4]
      date = Date.strptime(row[0],"%m/%d/%Y")
      hash_array << HashManager.new({'date' => date, 'tax_year' => date.year,
        'amount' => Money.new((100 * row[1].to_f).to_i), 'type_of' => row[2],
        'check_number' => row[3], 'description' => description})
    end
    sorted_array = hash_array.sort_by{|row| row.date}
    self.create(sorted_array.map{|row| row.to_hash}) if update == true
    return sorted_array
  end
=begin
  def self.csv_import(file_path = File.expand_path("~/Downloads/jr2017.csv"), init = false)
    if init
      self.delete_all
      sql = "ALTER TABLE `#{self.table_name}` AUTO_INCREMENT = 1"
      ActiveRecord::Base.connection.execute(sql)
    end
    csv = CSV.read(file_path)
    csv.shift
    csv.each do |row|
      description = row[4].nil? ? '' : row[4]
      hash = {'date' => Date.strptime(row[0],"%m/%d/%Y"),
        'amount' => Money.new((100 * row[1].to_f).to_i), 'type_of' => row[2],
        'check_number' => row[3], 'description' => description}
      self.create(hash)
    end
  end
=end
  def self.categorize(tax_year)
    fuel_cost = self.category_not_set.tax_year(tax_year).where("description is not null").
      select{|t| t.description.include?('CCD Brown') or t.description.include?('ACH CCD: Brown')}
    fuel_cost.each {|t| t.update_column(:category, 'fuel_cost')}

    sales = self.category_not_set.credit.tax_year(tax_year).where(:amount_cents => 800000..3000000)
    sales.each {|s| s.update_column(:category, 'fuel_sale')}

    commissions = self.category_not_set.tax_year(tax_year).debit.where(:amount_cents => 40000..80000)
    commissions.each {|s| s.update_column(:category, 'fuel_commission')}

    payments = self.category_not_set.tax_year(tax_year).debit.where("description is not null").
      select{|t| t.description.include?('Payment for Loan')}
    payments.each {|s| s.update_column(:category, 'loan_payment')}
  end

  def self.fuel_cost_spreadsheet
    items = Transaction.fuel_cost
    book = Spreadsheet::Workbook.new
		sheet = book.create_worksheet
		title_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 16
		header_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14
    #sheet.default_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14
    left_justified_format = Spreadsheet::Format.new :horizontal_align => :left, :size => 14
    right_justified_format = Spreadsheet::Format.new :horizontal_align => :right, :size => 14
    centre_justified_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14
    sheet.merge_cells(0, 0, 0, 2)
    sheet.merge_cells(1, 0, 0, 2)
    sheet.row(0).default_format = title_format
    sheet.row(0).push "2017 Fuel Cost Report"
    sheet.row(1).default_format = header_format
    sheet.row(1).push "Description", "Amount", "Date"
    row = 2
    total = Money.new(0)
    items.each do |item|
      sheet.row(row).set_format(0,left_justified_format)
      sheet.row(row).set_format(1,centred_justified_format)
      sheet.row(row).set_format(2,right_justified_format)
      sheet.row(row).push item.description, item.date.to_s, item.amount.to_f
      total += item.amount
      row += 1
    end
    row+=1
    sheet.row(row).set_format(0,left_justified_format)
    sheet.row(row).set_format(1,centred_justified_format)
    sheet.row(row).set_format(2,right_justified_format)
    sheet.row(row).push "TOTAL", "", total.to_f

    self.autofit(sheet)

    self.file_path = path + "/" + self.s3_key
    book.write self.file_path
  end

  def self.do_tax_year(tax_year)
    report = Transaction.new(tax_year)
  end

  # => *************************************************************************
  # => Helpers
  # => *************************************************************************

  def self.sales(tax_year)
    annual_rent = YearLease.rent(tax_year)
    transactions = Transaction.fuel_sale.tax_year(tax_year)
    fuel_sales = transactions.inject(Money.new(0)) {|total,t| total += t.amount}
    rent_transactions = Transaction.rent.tax_year(tax_year)
    total_rent = rent_transactions.inject(Money.new(0)) {|total,t| total += t.amount}
    return fuel_sales - annual_rent + total_rent
  end

  def self.cost(tax_year)
    transactions = Transaction.fuel_cost.tax_year(tax_year)
    return transactions.inject(Money.new(0)) {|total,t| total += t.amount}
  end

  def self.commission(tax_year)
    transactions = Transaction.fuel_commission.tax_year(tax_year)
    return transactions.inject(Money.new(0)) {|total,t| total += t.amount}
  end

  def self.fuel_profit(tax_year)
    return Transaction.sales(tax_year) + YearLease.rent(tax_year) -
      Transaction.cost(tax_year) - Transaction.commission(tax_year)
  end

  def self.balance_as_of(date)
    tax_year = date.year
    end_last_year_balance = Transaction.where(:tax_year => tax_year - 1).order("id desc").first.balance
    credits = Transaction.where(:tax_year => tax_year, :type_of => 'Credit').where("date <= ?",date)
    debits = Transaction.where(:tax_year => tax_year, :type_of => 'Debit').where("date <= ?",date)
    credit_amount = credits.map{|c| c.amount}.sum
    debit_amount = debits.map{|c| c.amount}.sum
    return end_last_year_balance + credit_amount - debit_amount
  end

  def self.balance(tax_year = Date.today.year)
    end_last_year_balance = Transaction.where(:tax_year => tax_year - 1).order("id desc").first.balance
    credits = Transaction.where(:tax_year => tax_year, :type_of => 'Credit')
    debits = Transaction.where(:tax_year => tax_year, :type_of => 'Debit')
    credit_amount = credits.map{|c| c.amount}.sum
    debit_amount = debits.map{|c| c.amount}.sum
    return end_last_year_balance + credit_amount - debit_amount
  end

  def self.item_balances(tax_year = Date.today.year)
    end_last_year_balance = Transaction.where(:tax_year => tax_year - 1).
      order("id desc").first.balance_cents
    items = Transaction.where(:tax_year => tax_year).order("id")
    current_balance = end_last_year_balance
    array = []
    items.each do |item|
      amount_cents = item.amount_cents
      amount_cents = -1 * amount_cents if item.type_of == 'Debit'
      current_balance += amount_cents
      puts "current_balance:  #{current_balance.to_f / 100.0}"
      hash = item.as_json
      hash['current_balance'] = current_balance
      array << HashManager.new(hash)
    end
    return array
  end

  def self.calculate_balances(tax_year = 2018)
    balance_transaction = Transaction.where("balance_cents != 0").where("tax_year < ?",tax_year).last
    transactions = Transaction.where("id > ?", balance_transaction.id).order("date, id")
    balance = balance_transaction.balance
    transactions.each do |transaction|
      balance += (transaction.type_of == 'Debit' ? -1.0 * transaction.amount : transaction.amount)
      transaction.balance = balance
      transaction.save!
    end
    return balance
  end

end
