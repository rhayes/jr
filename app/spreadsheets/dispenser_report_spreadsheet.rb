class DispenserReportSpreadsheet < SpreadsheetWorkbook

  def self.create(week)
    book = DispenserReportSpreadsheet.new
    book.build(week)
  end

  def build(week)
    dispenser_net = DispenserSale.net_for_week(week, true)
    dispenser_total = DispenserSale.week_report_data(week)
		sheet = create_worksheet

    set_column_widths(sheet, [12, 18, 18, 18, 18, 18, 18, 18, 18])
    merge_cells(sheet, [[0,0,1,8], [2, 1, 2, 2], [2, 3, 2, 4], [2, 5, 2, 6], [2, 7, 2, 8]])

    push_cell(sheet.row(0), 0, "Dispenser sales/gallons report(Tax Year: #{week.tax_year})\n" +
      "Week #{week.number}  -- #{week.date_range.first.to_s} thru #{week.date_range.last.to_s}", formath_center(12))

    push_row(sheet.row(2), ["Dispenser", "Regular", "", "Plus", "", "Premium", "", "Diesel"], formath_center(10))
    push_row(sheet.row(3), ["", "Sales", "Gallons", "Sales", "Gallons", "Sales", "Gallons", "Sales", "Gallons"], formath_center(10))

    sales = week.dispenser_sales.order("number")
    currency_format = formath_right(10, {:number_format => '##,##0.00'})

    cell_formats = [formath_center(10)] + Array.new(8, currency_format)
    row = nil

    sales.each_with_index do |dispenser, number|
      row = number + 4
      set_cell_formats(sheet.row(row), cell_formats)
      sheet.row(row).push dispenser.number,
        dispenser.regular_cents.to_f / 100.0, dispenser.regular_volume,
        dispenser.plus_cents.to_f / 100.0, dispenser.plus_volume,
        dispenser.premium_cents.to_f / 100.0, dispenser.premium_volume,
        dispenser.diesel_cents.to_f / 100.0, dispenser.diesel_volume
    end


    row += 1
    set_cell_formats(sheet.row(row), cell_formats)
    columns = ['TOTAL'] + dispenser_total.totals_array(false)
    columns.each {|column| sheet.row(row).push column}

    row += 1
    set_cell_formats(sheet.row(row), cell_formats)
    columns = ['ADJ TOTAL'] + dispenser_total.totals_array(true)
    columns.each {|column| sheet.row(row).push column}

    row += 1
    set_cell_formats(sheet.row(row), cell_formats)
    columns = ['NET'] + dispenser_net.totals_array(true)
    columns.each {|column| sheet.row(row).push column}

    filename = "#{week.date.year}_#{week.date.month.to_s.rjust(2,'0')}_#{week.date.day.to_s.rjust(2,'0')}"
    file_path = File.expand_path("~/Documents/jr_reports/#{week.tax_year}/weekly_dispenser_reports/dsp_#{filename}.xls")
    write file_path
  end

end
