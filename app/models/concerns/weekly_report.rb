module WeeklyReport

  extend ActiveSupport::Concern

  def create_dispenser_report(week)
    book = Spreadsheet::Workbook.new
		sheet = book.create_worksheet
    sheet.column(0).width = 12
    sheet.column(1).width = 18
    sheet.column(2).width = 18
    sheet.column(3).width = 18
    sheet.column(4).width = 18
    sheet.column(5).width = 18
    sheet.column(6).width = 18
    sheet.column(7).width = 18
    sheet.column(8).width = 18
		title_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 12
		header_format = Spreadsheet::Format.new :horizontal_align => :centre, :size =>10
    #sheet.default_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14
    left_justified_format = Spreadsheet::Format.new :horizontal_align => :left, :size =>10
    right_justified_format = Spreadsheet::Format.new :horizontal_align => :right, :size =>10
    centre_justified_format = Spreadsheet::Format.new :horizontal_align => :centre, :size =>10
    sheet.merge_cells(0,0,1,8)

    sheet.merge_cells(2, 1, 2, 2)
    sheet.merge_cells(2, 3, 2, 4)
    sheet.merge_cells(2, 5, 2, 6)
    sheet.merge_cells(2, 7, 2, 8)
    sheet.row(0).default_format = title_format
    sheet.row(0).push "Dispenser sales/gallons report(Tax Year: #{self.tax_year})\n" +
      "Week #{week.number}  -- #{week.date_range.first.to_s} thru #{week.date_range.last.to_s}"
    sheet.row(2).default_format = header_format
    sheet.row(2).push "Dispenser", "Regular", "", "Plus", "", "Premium", "", "Diesel"
    sheet.row(3).default_format = header_format
    sheet.row(3).push "", "Sales", "Gallons", "Money", "Volume", "Sales", "Gallons", "Sales", "Gallons"
    sales_rows = week.dispenser_sales.order("number")
    sales_rows = week.dispenser_sales_with_offset
    row = nil
    left_format = Spreadsheet::Format.new(:horizontal_align => :left, :size =>10)
		centre_format = Spreadsheet::Format.new(:horizontal_align => :centre, :size =>10)
		right_format = Spreadsheet::Format.new(:horizontal_align => :right,
			:size => 10, :number_format => '##,##0.00')
    last_row = sales_rows.count + 7
    for row in 4..last_row
      sheet.row(row).set_format(0, centre_format)
      sheet.row(row).set_format(1, right_format)
      sheet.row(row).set_format(2, right_format)
      sheet.row(row).set_format(3, right_format)
      sheet.row(row).set_format(4, right_format)
      sheet.row(row).set_format(5, right_format)
      sheet.row(row).set_format(6, right_format)
      sheet.row(row).set_format(7, right_format)
      sheet.row(row).set_format(8, right_format)
    end
    sales_rows.each_with_index do |sales_row, index|
      row = index + 4
      sheet.row(row).push sales_row.number,
        sales_row.regular_cents.to_f / 100.0, sales_row.regular_volume,
        sales_row.plus_cents.to_f / 100.0, sales_row.plus_volume,
        sales_row.premium_cents.to_f / 100.0, sales_row.premium_volume,
        sales_row.diesel_cents.to_f / 100.0, sales_row.diesel_volume
    end
    row += 1

    regular_money_total = sales_rows.map{|s| s.regular_cents}.sum.to_f / 100.0
    regular_volume_total = sales_rows.map{|s| s.regular_volume}.sum
    plus_money_total = sales_rows.map{|s| s.plus_cents}.sum.to_f / 100.0
    plus_volume_total = sales_rows.map{|s| s.plus_volume}.sum
    premium_money_total = sales_rows.map{|s| s.premium_cents}.sum.to_f / 100.0
    premium_volume_total = sales_rows.map{|s| s.premium_volume}.sum
    diesel_money_total = sales_rows.map{|s| s.diesel_cents}.sum.to_f / 100.0
    diesel_volume_total = sales_rows.map{|s| s.diesel_volume}.sum

    sheet.row(row).push "TOTAL", regular_money_total, regular_volume_total,
      plus_money_total, plus_volume_total,
      premium_money_total, premium_volume_total,
      diesel_money_total, diesel_volume_total

    last_week = Week.where("id < ?",week.id).last
    unless last_week.nil?
      #sales_rows = last_week.dispenser_sales.order("number")
      sales_rows = last_week.dispenser_sales_with_offset
      unless sales_rows.empty?
        previous_regular_money_total = regular_money_total - sales_rows.map{|s| s.regular_cents}.sum.to_f / 100.0
        previous_regular_volume_total = regular_volume_total - sales_rows.map{|s| s.regular_volume}.sum
        previous_plus_money_total = plus_money_total - sales_rows.map{|s| s.plus_cents}.sum.to_f / 100.0
        previous_plus_volume_total = plus_volume_total - sales_rows.map{|s| s.plus_volume}.sum
        previous_premium_money_total = premium_money_total - sales_rows.map{|s| s.premium_cents}.sum.to_f / 100.0
        previous_premium_volume_total = premium_volume_total - sales_rows.map{|s| s.premium_volume}.sum
        previous_diesel_money_total = diesel_money_total - sales_rows.map{|s| s.diesel_cents}.sum.to_f / 100.0
        previous_diesel_volume_total = diesel_volume_total - sales_rows.map{|s| s.diesel_volume}.sum

        sheet.row(row+1).push "WEEK",
          previous_regular_money_total, previous_regular_volume_total,
          previous_plus_money_total, previous_plus_volume_total,
          previous_premium_money_total, previous_premium_volume_total,
          previous_diesel_money_total, previous_diesel_volume_total
      end
    end

    #self.autofit(sheet)

    file_path = File.expand_path("~/Documents/jr/dispenser_reports/week_#{week.number.to_s.rjust(2,'0')}_#{week.date.year}.xls")
    book.write file_path
  end

  def volume_sync(current_week)
    previous_week = Week.where("id < ?",current_week.id).order("id desc").first

    current_tank_volume = current_week.tank_volume
    current_dispenser_volumes = current_week.dispenser_volumes
    previous_tank_volume = previous_week.tank_volume
    previous_dispenser_volumes = previous_week.dispenser_volumes
    sold_gallons =
    delivery_gallons = current_week.delivery_gallons

    previous_tank_volume = previous_week.tank_volume

    previous_gallons = previous_week.dispenser_volumes
    current_gallons = current_week.dispenser_volumes
    return (current_gallons[0] -previous_gallons[0]).to_f,
      (current_gallons[1] -previous_gallons[1]).to_f
  end

  def week_profit
    #total_last_week = Week.dispenser_totals(self.previous_week)
    #total_this_week = Week.dispenser_totals(self)
    total_last_week = self.previous_week.dispenser_totals
    total_this_week = self.dispenser_totals
    array = []
    grades = ['regular', 'plus', 'premium', 'diesel']
    rates_per_gallon = self.last_rate_per_gallon
    for i in 0..3
      hash = {'grade' => grades[i], 'cents' => total_this_week[i] - total_last_week[i],
        'gallons' => (total_this_week[i+4] - total_last_week[i+4]).to_f}
      hash['retail_rate'] = ((hash['cents'].to_f / hash['gallons'])/100.0).round(4)
      if hash['grade'] == 'regular'
        hash['cost_rate'] = rates_per_gallon.first
      elsif hash['grade'] == 'plus'
        hash['cost_rate'] = ((rates_per_gallon.first + rates_per_gallon[1])/2.0).round(4)
      elsif hash['grade'] == 'premium'
        hash['cost_rate'] = rates_per_gallon[1]
      elsif hash['grade'] == 'diesel'
        hash['cost_rate'] = rates_per_gallon.last
      end
      hash['gross_profit'] = hash['gallons'] * (hash['retail_rate'] - hash['cost_rate'])
      hash['net_profit'] = hash['gross_profit'] - (0.06 * hash['gallons'])
      array << hash
    end
    return array
=begin
    total_this_week.each_with_index do |this_week,index|
      total = this_week - total_last_week[index]
      total.kind_of?(Integer) ? totals << total : totals << total.to_f
    end
    grades_per_gallon = Week.last_rate_per_gallon
    return totals
=end
  end
  #protected

  def find_deposit
    sales = self.total_sales
    deposit_range = (sales.cents - 1000) .. (sales.cents + 1000)
    date_range = self.date..self.date+10.days
    deposit = Transaction.fuel_sale.where(:amount_cents => deposit_range, :date => date_range).first
    return deposit unless deposit.nil?
    sales -= Money.new(90000)
    deposit_range = (sales.cents - 1000) .. (sales.cents + 1000)
    deposit = Transaction.fuel_sale.where(:amount_cents => deposit_range, :date => date_range).first
  end

  def total_sales
    return self.to_date_sales(self) - self.to_date_sales(self.previous_week)
  end

  def to_date_sales(week)
    entries = week.dispenser_sales
    return entries.map{|e| e.regular + e.plus + e.premium + e.diesel}.sum
  end

end
