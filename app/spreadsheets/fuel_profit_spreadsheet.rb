class FuelProfitSpreadsheet < SpreadsheetWorkbook
  def self.formatted_date(date)
    date.to_s.gsub("-","_")
  end

  def self.create_report_for_week(week)
    spreadshhet = FuelProfitSpreadsheet.new
    spreadshhet.build_report_for_week(week)
  end

  def self.create_report_for_year(tax_year = 2019)
    spreadshhet = FuelProfitSpreadsheet.new
    last_week = Week.tax_year(tax_year).order(:id).last
    title = "#{tax_year} Detailed Estimated Fuel Profit"
    file_path = File.expand_path("~/Documents/jr_reports/#{tax_year}/fuel_profit_reports/defp_#{tax_year}_as_of_#{self.formatted_date(last_week.date)}.xls")
    spreadshhet.build_report_for_year(tax_year, title, file_path)
  end

  def self.create_report_for_weeks(week)
    spreadshhet = FuelProfitSpreadsheet.new
    spreadshhet.build_report_for_week(week)
  end

  def self.create_grade_details_year_to_date_report(tax_year = 2019)
    spreadsheet = FuelProfitSpreadsheet.new
    spreadsheet.build_grade_details_year_to_date_report(tax_year)
  end

  def self.test_file_path(tax_year)
    spreadsheet = FuelProfitSpreadsheet.new
    filename = "fdr_#{tax_year}.xls"
    file_path = spreadsheet.build_file_path([spreadsheet.fuel_profit_folder(tax_year), filename])
  end

  def build_grade_details_year_to_date_report(tax_year)
    report = FuelProfit.create_grade_details_year_to_date_report(tax_year)
    sheet = create_worksheet
    sheet.merge_cells(0, 0, 0, 4)
    sheet.row(0).default_format = formath_center(16)
    sheet.row(0).push "Totals by grade for #{tax_year}"
    sheet.row(1).default_format = formath_center(14)
    sheet.row(1).push "", "Regular", "Premium", "Diesel", "Total"

    data = [{:type => 'gallons', :title => 'Gallons', :format => {}},
      {:type => 'retail', :title => 'Retail', :format => {:number_format => '$#,###,##0.00'}},
      {:type => 'cost', :title => 'Cost', :format => {:number_format => '$#,###,##0.00'}},
      {:type => 'net', :title => 'Net', :format => {:number_format => '$#,###,##0.00'}},
      {:type => 'retail_per_gallon', :title => 'Retail Per Gallon', :format => {:number_format => '#0.0000'}},
      {:type => 'cost_per_gallon', :title => 'Cost Per Gallon', :format => {:number_format => '#0.0000'}},
      {:type => 'net_per_gallon', :title => 'Net Per Gallon', :format => {:number_format => '#0.0000'}}]

    columns = FuelDelivery::GRADES + ['total']
    data.each_with_index do |datum, index|
      sheet_row = sheet.row(index + 2)
      sheet_row.push datum[:title]
      format = datum[:format]
      data_type = datum[:type].to_s
      puts "data_type:  #{data_type}  --  "
      set_cell_formats(sheet_row, [formath_left(10), formath_right(10, format),
        formath_right(10, format), formath_right(10, format), formath_right(10, format)])
      columns.each {|column| sheet_row.push report.grade_profit.get_entry(column).send(data_type)}
    end

    auto_fit(sheet)

    filename = "fdr_#{tax_year}.xls"
    file_path = build_file_path([fuel_profit_folder(tax_year), filename])
    puts "file_path:  #{file_path}"
    write file_path
    return report
  end

  def build_report_for_week(week)
    report = FuelProfit.create_report_for_week(week)
    book = Spreadsheet::Workbook.new
		sheet = book.create_worksheet
=begin
    sheet.column(0).width = 15
    sheet.column(1).width = 15
    sheet.column(2).width = 18
    sheet.column(3).width = 18
    sheet.column(4).width = 15
    sheet.column(5).width = 18
=end
		title_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 16
		header_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14
    left_justified_format = Spreadsheet::Format.new :horizontal_align => :left, :size => 14
    right_justified_format = Spreadsheet::Format.new :horizontal_align => :right, :size => 14, :number_format => '#,###,##0.00'
    per_gallon_format = Spreadsheet::Format.new :horizontal_align => :right, :size => 14, :number_format => '##0.0000'
    centre_justified_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14

    sheet.merge_cells(0, 0, 0, 5)
    sheet.row(0).default_format = title_format
    beg_date = week.date - 6.days
    sheet.row(0).push "Estimated profit for #{beg_date.to_s} - #{week.date.to_s}"
    sheet.row(1).default_format = header_format
    sheet.row(1).push "Grade", "Gallons", "Retail", "Cost", "Net", 'Per Gallon'

    row = nil
    report.grade_profit.entries.each_with_index do |entry, index|
      row = index + 2
      set_row_format(sheet.row(row), [left_justified_format,
        right_justified_format, right_justified_format, right_justified_format,
        right_justified_format, per_gallon_format])
      sheet.row(row).push entry.description.titleize
      sheet.row(row).push entry.gallons.round(2)
      sheet.row(row).push entry.retail.round(2)
      sheet.row(row).push entry.cost.round(2)
      sheet.row(row).push entry.net.round(2)
      sheet.row(row).push entry.net_per_gallon.round(4)
    end

    report.fuel_detail._columns.each do |grade|
      row += 3
      sheet.merge_cells(row, 0, row, 5)
      sheet.row(row).default_format = header_format
      sheet.row(row).push "#{grade.capitalize} grade deliveries"
      row +=1
      sheet.row(row).default_format = header_format
      sheet.row(row).push "Date", "Invoice No", "Rate", "Gallons", "Applied", "Total Applied"
      deliveries = report.fuel_detail[grade].deliveries
      total_gallons_applied = 0
      deliveries.each_with_index do |delivery, index|
        row += 1
        self.set_row_format(sheet.row(row), [left_justified_format,
          centre_justified_format, per_gallon_format, right_justified_format,
          right_justified_format, right_justified_format])
        total_gallons_applied += delivery.gallons_applied
        sheet.row(row).push delivery.date.to_s, delivery.invoice_number,
          delivery.per_gallon, delivery.gallons,
          delivery.gallons_applied, total_gallons_applied
      end
    end

    auto_fit(sheet)

    filename = "#{week.date.year}_#{week.date.month.to_s.rjust(2,'0')}_#{week.date.day.to_s.rjust(2,'0')}"
    file_path = File.expand_path("~/Documents/jr_reports/#{week.tax_year}/fuel_profit_reports/fpr_#{filename}.xls")
    book.write file_path
  end

  def build_report_for_year(tax_year, title, file_path)
  end

  def build_report_for_weeks
  end

  def set_row_format(row, formats)
    formats.each_with_index {|format,index| row.set_format(index,format)}
  end
end
