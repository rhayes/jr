class FuelSalesDelivery

  attr_accessor   :weeks
  attr_accessor   :weekly_results
  attr_accessor   :total_results
  attr_accessor   :sales
  attr_accessor   :tank_volume_results
  attr_accessor   :tank_volume_projected
  attr_accessor   :fuel_deliveries

  def initialize(weeks)
    @weeks = weeks
    @weekly_results = nil
    @total_results = nil
  end

  def self.report(weeks)
    report = FuelSalesDelivery.new(weeks)
    report.build
    book = Spreadsheet::Workbook.new
		sheet = book.create_worksheet
    (0..9).each {|cell| sheet.column(cell).width = 15}

		title_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14
		header_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 12
    left_justified_format = Spreadsheet::Format.new :horizontal_align => :left, :size => 12
    right_justified_format = Spreadsheet::Format.new :horizontal_align => :right, :size => 12, :number_format => '#,###,##0.00'
    per_gallon_format = Spreadsheet::Format.new :horizontal_align => :right, :size => 12, :number_format => '####0.00'
    centre_justified_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 12

    sheet.merge_cells(0, 0, 0, 9)
    sheet.merge_cells(2, 1, 2, 3)
    sheet.merge_cells(2, 4, 2, 6)
    sheet.merge_cells(2, 7, 2, 9)

    sheet.row(0).default_format = title_format
    sheet.row(1).default_format = header_format
    sheet.row(2).default_format = header_format
    sheet.row(3).default_format = header_format

    sheet.row(0).push "Sales/Deliveries  #{weeks.first.date.to_s} thru #{weeks.last.date.to_s}"
    sheet.row(2).push '', 'Delivered', '', '', 'Sold', '', '', 'Balance'
    sheet.row(3).push 'Week', 'Regular', 'Premium', 'Diesel', 'Regular', 'Premium', 'Diesel', 'Regular', 'Premium', 'Diesel'

    row = nil
    report.weekly_results.each_with_index do |result,index|
      row = index + 4
      sheet.row(row).default_format = right_justified_format
      sheet.row(row).set_format(0, centre_justified_format)
      result.get_values.each {|value| sheet.row(row).push value}
    end

    row += 2
    sheet.row(row).default_format = right_justified_format
    sheet.row(row).set_format(0, centre_justified_format)
    report.total_results.get_values.each {|value| sheet.row(row).push value}

    row += 3
    sheet.merge_cells(row, 1, row, 3)
    sheet.row(row).default_format = centre_justified_format
    sheet.row(row).push "", "Deliveries Minus Sales"
    row += 1
    sheet.row(row).default_format = centre_justified_format
    sheet.row(row).push "", "Regular", "Plus", "Premium", "Diesel"
    titles = ['First Week', 'Last Week', 'Total', 'Total by grade', 'Delivered', 'Balance']
    report.sales.to_hash.keys.each_with_index do |key,index|
      row += 1
      sheet.row(row).default_format = right_justified_format
      sheet.row(row).set_format(0, left_justified_format)
      sheet.row(row).push titles[index]
      sheet.row(row).push report.sales.get_values(key).each {|value| sheet.row(row).push value}
    end

    row += 3
    sheet.merge_cells(row, 1, row, 3)
    sheet.row(row).default_format = centre_justified_format
    sheet.row(row).push "", "Tank Volume - Actual vs Calculated"
    row += 1
    sheet.row(row).default_format = centre_justified_format
    sheet.row(row).push "", "Regular", "Premium", "Diesel"
    grades = ["Regular", "Premium", "Diesel"]
    titles = ['First Week', 'Sales', 'Delivered', 'Calculated', 'Last Week', 'Difference']
    titles.each_with_index do |title,index|
      row += 1
      sheet.row(row).default_format = right_justified_format
      sheet.row(row).set_format(0, left_justified_format)
      sheet.row(row).push title
      week_before_volumes = report.tank_volume_results.get_values("week_before")
      sold = report.total_results.get_values_by_key('sold')
      delivered = report.total_results.get_values_by_key('delivered')
      calculated = [0,1,2].inject([]) {|c,index|
        c << week_before_volumes[index] + delivered[index] - sold[index];c}
      week_after_volumes = report.tank_volume_results.get_values("week_after")
      difference = [0,1,2].inject([]) {|d,index|
        d << calculated[index] - week_after_volumes[index];d}
      if index == 0
        week_before_volumes.each {|value| sheet.row(row).push value}
      elsif index == 1
        sold.each {|value| sheet.row(row).push value}
      elsif index == 2
        delivered.each {|value| sheet.row(row).push value}
      elsif index == 3
        calculated.each {|value| sheet.row(row).push value}
      elsif index == 4
        week_after_volumes.each {|value| sheet.row(row).push value}
      elsif index == 5
        difference.each {|value| sheet.row(row).push value}
      end
    end

    file_path = File.expand_path("~/Documents/jr/fuel_reports/sales_deliveries.xls")
    book.write file_path
    return report

  end

  def self.create(weeks)
    report = FuelSalesDelivery.new(weeks)
    report.build
    return report
  end

  def build
    self.weekly_results = []
    self.weeks.each do |current_week|
      net_sales = DispenserSalesTotal.net_sales_for_period(current_week.previous_week, current_week)
      delivered = self.total_delivered_by_grade(current_week.fuel_deliveries)
      balance = self.balance_gallons(net_sales, delivered)
      self.weekly_results << add_to_results(current_week.date, delivered, net_sales, balance)
    end
    total_fuel_deliveries = weeks.flat_map{|week| week.fuel_deliveries}
    total_delivered = self.total_delivered_by_grade(total_fuel_deliveries)
    total_net_sales = DispenserSalesTotal.net_sales_for_period(weeks.first.previous_week, weeks.last)
    total_balance = self.balance_gallons(total_net_sales, total_delivered)
    self.total_results = add_to_results('TOTAL', total_delivered, total_net_sales, total_balance)
    first_week_sales = DispenserSalesTotal.new(weeks.first.previous_week, true)
    last_week_sales = DispenserSalesTotal.new(weeks.last, true)
    total_sales = DispenserSalesTotal.net_sales_for_period(weeks.first.previous_week, weeks.last, true)
    total_sales_by_grade = DispenserSalesTotal.net_sales_for_period(weeks.first.previous_week, weeks.last, false)
    self.sales = Sales.new(first_week_sales, last_week_sales, total_sales,
      total_sales_by_grade, total_delivered)
    self.tank_volume_results = Volume.new(weeks.first.previous_week.tank_volume, weeks.last.tank_volume)

    self.fuel_deliveries = []
    total_fuel_deliveries.each do |delivery|
      transaction = delivery.fuel_transaction
      transaction.date = transaction.amount = nil
      unless transaction.nil?
        transaction.date = transaction.date.to_s
        transaction.amount = transaction.amount.to_f
      end
      self.fuel_deliveries << HashManager.new({'invoice_number' => delivery.invoice_number,
        'delivery_date' => delivery.delivery_date, 'regular' => delivery.regular_gallons,
        'premium' => delivery.supreme_gallons, 'diesel' => delivery.diesel_gallons,
        'transaction_date' => transaction.date, 'amount' => transaction.amount})
    end
    return self.weekly_results, self.total_results
  end

  def total_delivered_by_grade(fuel_deliveries)
    return HashManager.new('regular' => fuel_deliveries.map(&:regular_gallons).sum,
           'premium' => fuel_deliveries.map(&:supreme_gallons).sum,
           'diesel' => fuel_deliveries.map(&:diesel_gallons).sum)
  end

  def balance_gallons(net_sales, delivered)
    return HashManager.new('regular' => delivered.regular - net_sales.regular.gallons,
    'premium' => delivered.premium - net_sales.premium.gallons,
    'diesel' => delivered.diesel - net_sales.diesel.gallons)
  end

  def add_to_results(first_column, delivered, net_sales, balance)
    return SingleWeek.new({'week' => first_column,
      'delivered' => {'regular' => delivered.regular, 'premium' => delivered.premium, 'diesel' => delivered.diesel},
      'sold' => {'regular' => net_sales.regular.gallons, 'premium' => net_sales.premium.gallons, 'diesel' => net_sales.diesel.gallons},
      'balance' => {'regular' => balance.regular, 'premium' => balance.premium, 'diesel' => balance.diesel}})
  end

  class SingleWeek < HashManager
    def get_values
      values = [self.week.to_s]
      (self.to_hash.keys - ['week']).each do |column|
        row = self.public_send(column)
        row.to_hash.keys.each {|key| values << row.public_send(key)}
      end
      return values
    end

    def get_values_by_key(key)
      row = self.public_send(key)
      values = []
      row.to_hash.keys.each {|column| values << row.public_send(column)}
      return values
    end
  end

  class Sales < HashManager
    def initialize(first_week_sales, last_week_sales, total_sales, total_sales_by_grade, delivered)
      grades = first_week_sales.to_hash.keys
      hash = {'first_week_sales' => inject_row(grades, first_week_sales.to_hash)}
      hash['last_week_sales'] = inject_row(grades, last_week_sales.to_hash)
      hash['total_sales'] = inject_row(grades, total_sales.to_hash)
      hash['total_sales_by_grade'] = inject_row(grades, total_sales_by_grade.to_hash)
      hash['delivered'] = grades.inject({}) {|hash,grade| hash[grade] = delivered.to_hash[grade]; hash}
      hash['balance'] = {}
      grades.each do |grade|
        hash['balance'][grade] = grade == 'plus' ? nil :
          delivered.public_send(grade) - total_sales_by_grade.public_send(grade).gallons
      end
      super(hash)
    end
    def inject_row(grades, sales_hash)
      return grades.inject({}) {|hash,grade| hash[grade] = inject_column(grade, sales_hash); hash}
    end
    def inject_column(grade, sales_hash)
      row = sales_hash[grade]
      return row.nil? ? nil : row['gallons']
    end
    def get_values(key)
      row = self.public_send(key)
      return row.to_hash.keys.inject([]) {|array,key| array << row.public_send(key); array}
    end
  end

  class Volume < HashManager
    def initialize(first_week, last_week)
      grades = ['regular', 'premium', 'diesel']
      hash = {}
      hash['week_before'] = inject_row(grades, first_week)
      hash['week_after'] = inject_row(grades, last_week)
      hash['difference'] = grades.inject({}) {|h,grade| h[grade] = first_week[grade] - last_week[grade];h}
      super(hash)
    end
    def inject_row(grades, tank_volume)
      return grades.inject({}) {|hash,grade| hash[grade] = tank_volume[grade]; hash}
    end
    def get_values(key)
      row = self.public_send(key)
      return row.to_hash.keys.inject([]) {|array,key| array << row.public_send(key); array}
    end
  end
end
