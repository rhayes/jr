class DispenserReportSpreadsheet
  def self.build(week)
    dispenser_net = DispenserSale.net_for_week(week, true)
    dispenser_total = DispenserSale.week_report_data(week)
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
    sheet.row(0).push "Dispenser sales/gallons report(Tax Year: #{week.tax_year})\n" +
      "Week #{week.number}  -- #{week.date_range.first.to_s} thru #{week.date_range.last.to_s}"
    sheet.row(2).default_format = header_format
    sheet.row(2).push "Dispenser", "Regular", "", "Plus", "", "Premium", "", "Diesel"
    sheet.row(3).default_format = header_format
    sheet.row(3).push "", "Sales", "Gallons", "Money", "Volume", "Sales", "Gallons", "Sales", "Gallons"

    sales = week.dispenser_sales.order("number")
    #sales_rows = week.dispenser_sales_with_offset
    #row = nil
    left_format = Spreadsheet::Format.new(:horizontal_align => :left, :size =>10)
		centre_format = Spreadsheet::Format.new(:horizontal_align => :centre, :size =>10)
		right_format = Spreadsheet::Format.new(:horizontal_align => :right,
			:size => 10, :number_format => '##,##0.00')
    #last_row = sales_rows.count + 7
    column_formats = [centre_format, right_format, right_format, right_format,
      right_format, right_format, right_format, right_format, right_format]
    row = nil

    sales.each_with_index do |dispenser, number|
      row = number + 4
      DispenserReportSpreadsheet.set_row_formats(sheet.row(row), column_formats)
      sheet.row(row).push dispenser.number,
        dispenser.regular_cents.to_f / 100.0, dispenser.regular_volume,
        dispenser.plus_cents.to_f / 100.0, dispenser.plus_volume,
        dispenser.premium_cents.to_f / 100.0, dispenser.premium_volume,
        dispenser.diesel_cents.to_f / 100.0, dispenser.diesel_volume
    end


    row += 1
    DispenserReportSpreadsheet.set_row_formats(sheet.row(row), column_formats)
    columns = ['TOTAL'] + dispenser_total.totals_array(false)
    columns.each {|column| sheet.row(row).push column}

    row += 1
    DispenserReportSpreadsheet.set_row_formats(sheet.row(row), column_formats)
    columns = ['ADJ TOTAL'] + dispenser_total.totals_array(true)
    columns.each {|column| sheet.row(row).push column}

    row += 1
    DispenserReportSpreadsheet.set_row_formats(sheet.row(row), column_formats)
    columns = ['NET'] + dispenser_net.totals_array(true)
    columns.each {|column| sheet.row(row).push column}

    filename = "#{week.date.year}_#{week.date.month.to_s.rjust(2,'0')}_#{week.date.day.to_s.rjust(2,'0')}"
    file_path = File.expand_path("~/Documents/jr_reports/#{week.tax_year}/weekly_dispenser_reports/wdr_#{filename}.xls")
    book.write file_path
  end

  def self.set_row_formats(row, column_formats)
    column_formats.each_with_index do |format, column|
      row.set_format(column, format)
    end
  end
end
