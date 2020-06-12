class PostWeeklyData

  attr_accessor   :week
  attr_accessor   :sheet
  attr_accessor   :row

  def self.perform(week)
    instance = self.new
    instance.week = week
    instance.post
  end

  def post
    filename = File.expand_path("~/Documents/jr_reports/2020/posting_data/week_#{week.id}.xls")
    book = Spreadsheet.open(filename)

    self.sheet = book.worksheets.select{|ws| ws.name == 'dispenser'}.first
    post_dispensers

    self.sheet = book.worksheets.select{|ws| ws.name == 'fuel'}.first
    post_fuel

    self.sheet = book.worksheets.select{|ws| ws.name == 'transactions'}.first
    post_transactions

    unmatched_deliveries = FuelDelivery.unmatched
    unmatched_deliveries.each {|delivery| delivery.match_transaction}

    Transaction.calculate_balances
  end

  def post_fuel
    result = find_keyword('Fuel', 0)
    raise "'Fuel' not found!" if result == false
    volume = TankVolume.where(:week_id => week.id).first_or_create!
    loop do
      self.row = sheet.row(row.idx + 1)
      break if row[0].nil?
      volume[row[0]] = row[1]
    end
    volume.save!

    loop do
      result = find_keyword('Invoice No', row.idx)
      break if (result == false) || !next_row[0].kind_of?(Fixnum)
      delivery = FuelDelivery.where(:invoice_number => row[0],
        :week_id => week.id, :delivery_date => row[1]).first_or_create!
      delivery.monthly_tank_charge_cents = Money.new(100*row[2]).cents
      delivery.adjustment_cents = Money.new(100*row[3]).cents
      loop do
        break if row[4].nil?
        grade_name = row[4]
        delivery[grade_name + "_gallons"] = row[5]
        delivery[grade_name + "_per_gallon"] = row[6]
        next_row
      end
      delivery.save!
    end
  end

  def post_dispensers
    self.row = sheet.row(0)
    loop do
      result = find_keyword('Dispenser', row.idx)
      break if (result == false) || !next_row[0].kind_of?(Fixnum)
      sales = DispenserSale.where(:week_id => week.id, :number => row[0]).first_or_create!
      loop do
        grade_name = row[1]
        break if grade_name.nil?
        sales[grade_name + "_cents"] = Money.new(100*row[3]).cents
        sales[grade_name + "_volume"] = row[2]
        sales[grade_name + "_dollars_adjustment"] = -row[5]
        sales[grade_name + "_volume_adjustment"] = -row[4]
        next_row
      end
      sales.save!
    end
  end

    def post_transactions
      return if find_keyword('Date', 0) == false
      entry_number = 0
      transaction_types = Transaction.pluck(:category).uniq
      loop do
        next_row
        break if row[0].nil? || !row[0].kind_of?(Date)
        category = row[2]
        raise "'#{category}' is invalid category!" unless transaction_types.include?(category)
        sequence = week.id.to_s + "-" + entry_number.to_s.rjust(3,'0')
        transaction = Transaction.find_by_posting_sequence(sequence)
        transaction = Transaction.new(:posting_sequence => sequence) if transaction.nil?
        transaction.date = row[0]
        transaction.amount = row[1]
        transaction.category = category
        transaction.type_of = ['fuel_sale','rent'].include?(category) ? 'credit' : 'debit'
        transaction.description = row[3].nil? ? "" : row[3]
        transaction.check_number = row[4]
        transaction.tax_year = (row[5] == 0) ? week.tax_year : row[5]
        transaction.fuel_delivery_id = (row[6] == 0) ? nil : row[6]
        transaction.week_id = (row[7] == 0) ? week.id : row[7]
        transaction.balance = 0.0
        transaction.save!
        entry_number += 1
      end
    end

  def find_keyword(keyword, starting_row_no)
    for i in starting_row_no..starting_row_no+9
      self.row = sheet.row(i)
      return true if row[0].kind_of?(String) && row[0].downcase.include?(keyword.downcase)
    end
    return false
  end

  def next_row
    self.row = sheet.row(row.idx + 1)
  end

end
