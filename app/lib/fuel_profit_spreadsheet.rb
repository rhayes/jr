class FuelProfitSpreadsheet < Spreadsheet::Workbook
  def self.create_weekly_report(week)
    spreadshhet = FuelProfitSpreadsheet.new
    spreadshhet.build_weekly_report(week)
  end

  def build_weekly_report(week)
    report = FuelProfit.create_weekly_report(week)
    book = Spreadsheet::Workbook.new
		sheet = book.create_worksheet
    sheet.column(0).width = 15
    sheet.column(1).width = 15
    sheet.column(2).width = 18
    sheet.column(3).width = 18
    sheet.column(4).width = 15
    sheet.column(5).width = 18

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
        self.set_row_format(sheet.row(row), [centre_justified_format,
          centre_justified_format, per_gallon_format, right_justified_format,
          right_justified_format, right_justified_format])
        total_gallons_applied += delivery.gallons_applied
        sheet.row(row).push delivery.date.to_s, delivery.invoice_number,
          delivery.per_gallon, delivery.gallons,
          delivery.gallons_applied, total_gallons_applied
      end
    end

    filename = "#{week.date.year}_#{week.date.month.to_s.rjust(2,'0')}_#{week.date.day.to_s.rjust(2,'0')}"
    file_path = File.expand_path("~/Documents/jr_reports/#{week.tax_year}/fuel_profit_reports/fpr_#{filename}.xls")
    book.write file_path
  end

  def set_row_format(row, formats)
    formats.each_with_index {|format,index| row.set_format(index,format)}
  end
end
