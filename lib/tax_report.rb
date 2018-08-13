class TaxReport
  #require 'CSV'

  attr_accessor   :tax_year
  attr_accessor   :annual_lease
  attr_accessor   :fuel_sales
  attr_accessor   :fuel_cost
  attr_accessor   :fuel_commission
  attr_accessor   :fuel_profit
  attr_accessor   :applicable_debit_codes
  attr_accessor   :other_costs
  attr_accessor   :details
  attr_accessor   :spreadsheet_rows
  attr_accessor   :credit_total
  attr_accessor   :debit_total

  def initialize(tax_year)
    @tax_year = tax_year
    @annual_lease = @fuel_sales = @commission = @fuel_cost = @credit_total = @debit_total = nil
    @other_costs = []
    @details = []
    @spreadsheet_rows = []
  end

  def self.generate(tax_year, include_loan_payment = false)
    report = self.new(tax_year)
    report.annual_lease = YearLease.rent(tax_year)
    report.do_the_report(include_loan_payment)
    return report
  end

  def do_the_report(include_loan_payment = false)
    skip_debit_categories = ['loan_payment','not_set','fuel_cost','fuel_commission','personal']
    if include_loan_payment
      skip_debit_categories = ['not_set','fuel_cost','fuel_commission','personal']
    end

    total_rent = self.category_total('rent')
    sales_including_rent = self.category_total('fuel_sale')
    self.fuel_sales = sales_including_rent - self.annual_lease
    self.spreadsheet_rows << HashManager.new({:type => 'credit', :category => 'fuel_sale', :amount_cents => fuel_sales.cents})
    self.spreadsheet_rows << HashManager.new({:type => 'credit', :category => 'rent', :amount_cents => self.annual_lease.cents})
    self.fuel_cost = self.category_total('fuel_cost')
    self.spreadsheet_rows << HashManager.new({:type => 'debit', :category => 'fuel_cost', :amount_cents => fuel_cost.cents})
    self.fuel_commission = self.category_total('fuel_commission')
    self.spreadsheet_rows << HashManager.new({:type => 'debit', :category => 'fuel_commission', :amount_cents => fuel_commission.cents})
    self.fuel_profit = self.fuel_sales - self.fuel_cost - self.fuel_commission
    self.applicable_debit_codes = Transaction.debit.tax_year(self.tax_year).map(&:category).uniq - skip_debit_categories
    self.other_costs = []
    self.applicable_debit_codes.each do |debit_code|
      cost = self.category_total(debit_code)
      details = Transaction.tax_year(2018).category(debit_code)
      self.other_costs << HashManager.new({:debit_code => debit_code,
        :cost_cents => cost.cents, :details => details.as_json})
      self.spreadsheet_rows << HashManager.new({:type => 'debit', :category => debit_code,
        :amount_cents => cost.cents, :details => details.as_json})
    end
    unless include_loan_payment
      interest = LoanInterest.where(:tax_year => self.tax_year).first
      unless interest.nil?
        self.other_costs << HashManager.new({:debit_code => 'mortgate_interest',
          :cost_cents => interest.amount.cents, :details => 'Mortgage Interest'})
        self.spreadsheet_rows << HashManager.new({:type => 'debit', :category => 'mortgage_interest',
          :amount_cents => interest.amount.cents, :details => 'Mortgage Interest'})
      end
    end
    self.credit_total = spreadsheet_rows.select{|r| r.type == 'credit'}.map(&:amount_cents).sum
    self.debit_total = spreadsheet_rows.select{|r| r.type == 'debit'}.map(&:amount_cents).sum
    #self.credit_total = spreadsheet_rows.select{|r| r[:type] == 'credit'}.map(&:amount_cents).sum
    #self.debit_total = spreadsheet_rows.select{|r| r[:type] == 'debit'}.map(&:amount_cents).sum
    self.do_spreadsheet
    return
    category_rows = Transaction.tax_year(self.tax_year).group(:category).select(:category).count
    category_rows.each do |row|
      detail_row = self.details.select{|d| c.category = row[0]}.first
      detail_row.count = row[1]
    end
  end

  def other_costs_total
    return self.other_costs.inject(Money.new(0)) {|total,item| total+=item[:cost];total}
  end

  def category_total(category)
    transactions = Transaction.where(:category => category).tax_year(tax_year)
    return transactions.inject(Money.new(0)) {|total,t| total += t.amount}
    self.details << HashManager.new({'category' => category, 'cost' => cost, 'count' => 0})
  end

  def category_count(category)
  end

  def do_spreadsheet
    book = Spreadsheet::Workbook.new
		sheet = book.create_worksheet
    sheet.column(0).width = 25
    sheet.column(1).width = 25
    sheet.column(2).width = 18
    sheet.column(3).width = 18
		title_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 16
		header_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14
    #sheet.default_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14
    left_justified_format = Spreadsheet::Format.new :horizontal_align => :left, :size => 14
    right_justified_format = Spreadsheet::Format.new :horizontal_align => :right, :size => 14, :number_format => '#,###,##0.00'
    centre_justified_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14
    sheet.merge_cells(0, 0, 0, 3)
    sheet.row(0).default_format = title_format
    sheet.row(0).push "#{self.tax_year} Tax Info"
    sheet.row(1).default_format = header_format
    sheet.row(1).push "Category", "Description", "Debit", "Credit"
    row = 2
    total = Money.new(0)
    self.spreadsheet_rows.each do |line|
      sheet.row(row).set_format(0,left_justified_format)
      sheet.row(row).set_format(1,left_justified_format)
      sheet.row(row).set_format(2,right_justified_format)
      sheet.row(row).set_format(3,right_justified_format)
      if line.type == 'debit'
        sheet.row(row).push self.category_title(line.category), nil, Money.new(line.amount_cents).to_f, nil
      else
        sheet.row(row).push self.category_title(line.category), nil, nil, Money.new(line.amount_cents).to_f
      end
      row += 1
    end
    row += 1
    sheet.row(row).set_format(0,left_justified_format)
    sheet.row(row).set_format(1,left_justified_format)
    sheet.row(row).set_format(2,right_justified_format)
    sheet.row(row).set_format(3,right_justified_format)
    total_debit = spreadsheet_rows.select{|r| r.type == 'debit'}.
      map(&:amount_cents).map{|cents| Money.new(cents)}.sum.to_f
    total_credit = spreadsheet_rows.select{|r| r.type == 'credit'}.
      map(&:amount_cents).map{|cents| Money.new(cents)}.sum.to_f
    sheet.row(row).push 'TOTAL', nil, total_debit, total_credit

    #self.autofit(sheet)

    #file_path = File.expand_path("~/Documents/jr/dispenser_reports/week_#{week.number.to_s.rjust(2,'0')}_#{week.date.year}.xls")
    file_path = File.expand_path("~/Documents/jr/tax_reports/jr_tax_info_#{self.tax_year}")
    book.write file_path
  end

  def category_title(category)
    return category.split('_').map(&:capitalize).join(' ')
  end
end
