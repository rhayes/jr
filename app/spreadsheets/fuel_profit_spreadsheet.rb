class FuelProfitSpreadsheet < SpreadsheetWorkbook
  def self.formatted_date(date)
    date.to_s.gsub("-","_")
  end

  def self.create_weekly_report(week)
    spreadsheet = FuelProfitSpreadsheet.new
    spreadsheet.build_weekly_report(week)
  end

  def self.create_detailed_annual_report_year_to_date(tax_year = 2019)
    weeks = Week.tax_year(tax_year).where("date < ?",Date.today).order(:id)
    self.do_detailed_annual_report(weeks)
  end

  def self.create_detailed_annual_report(week)
    weeks = Week.tax_year(week.tax_year).where("id <= ?", week.id).order(:id)
    self.do_detailed_annual_report(weeks)
  end

  def self.do_detailed_annual_report(weeks)
    spreadsheet = FuelProfitSpreadsheet.new
    tax_year = weeks.last.tax_year
    as_of = "#{self.formatted_date(weeks.last.date)}"
    title = "#{tax_year} Detailed Fuel Profit as of #{as_of.gsub("_", "-")}"
    file_path = File.expand_path("~/Documents/jr_reports/#{tax_year}/fuel_profit_reports/dpy_#{tax_year}_as_of_#{as_of}.xls")
    spreadsheet.build_detail_report(weeks, title, file_path)
  end

  def self.create_grade_details_year_to_date_report(tax_year = 2019)
    spreadsheet = FuelProfitSpreadsheet.new
    spreadsheet.build_summary_annual_report(tax_year)
  end

  def self.create_summary_annual_report(week)
    weeks = Week.tax_year(week.tax_year).where("id <= ?", week.id).order(:id)
    self.do_summary_annual_report(weeks)
  end

  def self.do_summary_annual_report(weeks)
    spreadsheet = FuelProfitSpreadsheet.new
    tax_year = weeks.last.tax_year
    as_of = "#{self.formatted_date(weeks.last.date)}"
    title = "#{tax_year} Fuel Profit Summary as of #{as_of.gsub("_", "-")}"
    file_path = File.expand_path("~/Documents/jr_reports/#{tax_year}/fuel_profit_reports/spy_#{tax_year}_as_of_#{as_of}.xls")
    spreadsheet.build_summary_annual_report(weeks, title, file_path)
  end

  def self.test_file_path(tax_year)
    spreadsheet = FuelProfitSpreadsheet.new
    filename = "fpy_#{tax_year}.xls"
    file_path = spreadsheet.build_file_path([spreadsheet.fuel_profit_folder(tax_year), filename])
  end

  def build_summary_annual_report(weeks, title, file_path)
    report = FuelProfit.create_summary_annual_report(weeks)
    sheet = create_worksheet
    tax_year = weeks.last.tax_year

    set_column_widths(sheet, [18, 15, 15, 15, 15])
    merge_cells(sheet, [[0,0,0,4]])

    push_cell(sheet.row(0), 0, title, formath_center(16))
    push_row(sheet.row(1), ["Description", "Regular", "Premium", "Diesel", "Total"], formath_center(14))

    data = [{:type => 'gallons', :title => 'Gallons', :format => {:number_format => '#,###,##0.00'}},
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
      set_cell_formats(sheet_row, [formath_left(10), formath_right(10, format),
        formath_right(10, format), formath_right(10, format), formath_right(10, format)])
      columns.each {|column| sheet_row.push report.grade_profit.get_entry(column).send(data_type)}
    end

    row_no = data.count + 4
    merge_cells(sheet, [[row_no,0,row_no,4]])

    push_cell(sheet.row(row_no), 0, "Fuel Volume Balance", formath_center(16))
    push_row(sheet.row(row_no+1), ["Description", "Regular", "Premium", "Diesel", "Total"], formath_center(14))

    number_format = {:number_format => '#,###,##0.00'}
    beginning_volume = weeks.first.previous_week.tank_volume
    ending_volume = weeks.last.tank_volume
    gallons_sold = report.net_sales.gallons
    gallons_delivered = FuelDelivery.summary(weeks)
    calculated = HashManager.new({:regular => nil, :premium => nil, :diesel => nil, :total => nil})
    calculated._columns.each {|grade| calculated[grade] = beginning_volume.send(grade) +
      gallons_delivered.send(grade) - gallons_sold.send(grade)}
    difference = HashManager.new({:regular => nil, :premium => nil, :diesel => nil, :total => nil})
    difference._columns.each {|grade| difference[grade] = ending_volume.send(grade) - calculated.send(grade)}

    row_defs = [["Beginning Volume", beginning_volume], ["Sales", gallons_sold], ["Delivered", gallons_delivered],
      ["Calculated", calculated], ["Ending Volume", ending_volume], ["Difference", difference]]
    row_defs.each_with_index do |row_def, index|
      sheet_row = sheet.row(row_no + index + 2)
      set_cell_formats(sheet_row, [formath_left(10)] + Array.new(4, formath_right(10, number_format)))
      push_row(sheet_row, columns.inject([row_def.first]) {|array,c| array << row_def.last.send(c); array})
    end

    write file_path
    return report
  end
=begin
  def build_summary_annual_report(tax_year)
    report = FuelProfit.create_grade_details_year_to_date_report(tax_year)
    sheet = create_worksheet

    set_column_widths(sheet, [18, 15, 15, 15, 15])
    merge_cells(sheet, [[0,0,0,4]])

    push_cell(sheet.row(0), 0, "Totals by grade for #{tax_year}", formath_center(16))
    push_row(sheet.row(1), ["", "Regular", "Premium", "Diesel", "Total"], formath_center(14))

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

    filename = "fpy_#{tax_year}.xls"
    file_path = build_file_path([fuel_profit_folder(tax_year), filename])
    puts "file_path:  #{file_path}"
    write file_path
    return report
  end
=end
  def build_weekly_report(week)
    report = FuelProfit.create_weekly_report(week)
    book = Spreadsheet::Workbook.new
		sheet = book.create_worksheet

    set_column_widths(sheet, [15, 15, 18, 18, 15, 18])
    merge_cells(sheet, [[0, 0, 0, 5]])

    header_format = formath_center(14)
    text_format = formath_left(14)
    currency_format = formath_right(14, {:number_format => '##0.00'})
    per_gallon_format = formath_right(14, {:number_format => '##0.00¢'})    #per_gallon_format = Spreadsheet::Format.new :horizontal_align => :right, :size => 14, :number_format => '##0.0000'
    center_format = formath_center(14)

    beg_date = week.date - 6.days
    push_cell(sheet.row(0), 0, "Estimated profit for #{beg_date.to_s} - #{week.date.to_s}", formath_center(16))
    push_row(sheet.row(1), ["Grade", "Gallons", "Retail", "Cost", "Net", "Per Gallon"], header_format)

    row_number = nil
    report.grade_profit.entries.each_with_index do |entry, index|
      row_number = index + 2
      row = sheet.row(row_number)
      formats = [text_format] + Array.new(4,currency_format) + [per_gallon_format]
      set_cell_formats(row, formats)
      row.push entry.description.titleize
      row.push entry.gallons.round(2)
      row.push entry.retail.round(2)
      row.push entry.cost.round(2)
      row.push entry.net.round(2)
      row.push (100.0 * entry.net_per_gallon).round(2)
    end

    FuelDelivery::GRADES.each do |grade|
      row_number += 3
      sheet.merge_cells(row_number, 0, row_number, 5)
      sheet.row(row_number).default_format = header_format
      sheet.row(row_number).push "#{grade.capitalize} grade deliveries"
      row_number +=1
      sheet.row(row_number).default_format = header_format
      sheet.row(row_number).push "Date", "Invoice No", "Rate", "Gallons", "Applied", "Total Applied"
      deliveries = report.fuel_detail[grade].deliveries
      total_gallons_applied = 0
      deliveries.each_with_index do |delivery, index|
        row_number += 1
        set_cell_formats(sheet.row(row_number), [text_format, center_format] + Array.new(4, currency_format))
        total_gallons_applied += delivery.gallons_applied
        sheet.row(row_number).push delivery.date.to_s, delivery.invoice_number,
          delivery.per_gallon, delivery.gallons,
          delivery.gallons_applied, total_gallons_applied
      end
    end

    filename = "#{week.date.year}_#{week.date.month.to_s.rjust(2,'0')}_#{week.date.day.to_s.rjust(2,'0')}"
    file_path = File.expand_path("~/Documents/jr_reports/#{week.tax_year}/fuel_profit_reports/fpw_#{filename}.xls")
    book.write file_path
  end
=begin
  def build_report_for_year(tax_year, title, file_path)
    weeks = Week.tax_year(tax_year).order(:id)
    reports = weeks.inject([]) {|array,week| FuelProfit.create_weekly_report(week);array}
    sheet = create_worksheet

    set_column_widths(sheet, [15, 12, 12, 12, 12, 12, 12, 12, 12])
    merge_cells(sheet, [[0,0,0,8]])
    merge_cells(sheet, [[1,6,1,8]])

    push_cell(sheet.row(0), 0, "Fuel profit for #{tax_year}", formath_center(16))
    push_row(sheet.row(1), ["Week", "Gallons", "Retail", "Cost", "Net", "Overall", "Regular", "Premium", "Diesel"], formath_center(14))

    data = [{:type => 'gallons', :title => 'Gallons', :format => {}},
      {:type => 'retail', :title => 'Retail', :format => {:number_format => '$#,###,##0.00'}},
      {:type => 'cost', :title => 'Cost', :format => {:number_format => '$#,###,##0.00'}},
      {:type => 'net', :title => 'Net', :format => {:number_format => '$#,###,##0.00'}},
      {:type => 'retail_per_gallon', :title => 'Retail Per Gallon', :format => {:number_format => '#0.0000'}},
      {:type => 'cost_per_gallon', :title => 'Cost Per Gallon', :format => {:number_format => '#0.0000'}},
      {:type => 'net_per_gallon', :title => 'Net Per Gallon', :format => {:number_format => '#0.0000'}}]

		#sheet = create_worksheet

    set_column_widths(sheet, [15, 15, 18, 18, 15, 18])
    merge_cells(sheet, [[0, 0, 0, 5]])

		#title_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 16
		#header_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14
    header_format = formath_center(14)
    text_format = formath_left(14)
    currency_format = formath_right(14, {:number_format => '##0.0000'})
    per_gallon_format = Spreadsheet::Format.new :horizontal_align => :right, :size => 14, :number_format => '##0.0000'
    center_format = formath_center(14)
    #centre_justified_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14

    #sheet.row(0).default_format = title_format
  end
=end
  def build_detail_report(weeks, title, file_path)
    sheet = create_worksheet

    set_column_widths(sheet, [15, 15, 15, 15, 15, 12, 12, 12, 12])
    merge_cells(sheet, [[0,0,0,8]])
    sheet.merge_cells(1, 0, 1, 4)
    sheet.merge_cells(1, 5, 1, 8)

    push_cell(sheet.row(0), 0, title, formath_center(16))
    push_row(sheet.row(1), ["", "", "", "", "", "Per Gallon"], formath_center(14))
    push_row(sheet.row(2), ["Week", "Gallons", "Retail", "Cost", "Net", "Overall", "Regular", "Premium", "Diesel"], formath_center(14))

    number_format = formath_right(10, {:number_format => "###,##0.00"})
    percent_format = formath_right(10, {:number_format => "#0.00¢"})
    date_format = formath_center(10, {:number_format => 'mm/dd/yyyy'})

    summary = YearToDateSummary.new
    weeks.each_with_index do |week,index|
      report = FuelProfit.create_weekly_report(week)
      row = sheet.row(index + 3)
      set_row_format(row, [date_format, number_format,
        number_format, number_format, number_format, percent_format,
        percent_format, percent_format, percent_format])
      grade_profit = report.grade_profit
      total = grade_profit.total
      per_gallon_array = (['total'] + FuelDelivery::GRADES).inject([]) {|array,grade| array << 100 * grade_profit[grade].net_per_gallon;array}
      push_row(row, [week.date, total.gallons, total.retail, total.cost, total.net] + per_gallon_array)
      summary.add(grade_profit)
    end
    row = sheet.row(weeks.count + 4)
    set_row_format(row, [formath_center(10), number_format,
      number_format, number_format, number_format])
    row.push "TOTAL", summary.gallons, summary.retail, summary.cost, summary.net
    row = sheet.row(weeks.count + 6)
    set_row_format(row, [formath_center(10), number_format,
      number_format, number_format, number_format, percent_format,
      percent_format, percent_format, percent_format])
    (["AVERAGE"] + summary.average).each {|av| row.push av}

    write file_path
  end

  def set_row_format(row, formats)
    formats.each_with_index {|format,index| row.set_format(index,format)}
  end

  class YearToDateSummary < HashManager
    attr_accessor   :count
    def initialize
      @count = 0
      hash = {:gallons => 0.0, :retail => 0.0, :cost => 0.0, :net => 0.0}
      (['total'] + FuelDelivery::GRADES).inject(hash) {|h,grade| hash.merge!({grade => 0.0}); h}
      super(hash)
    end

    def add(weekly)
      self.count += 1
      self._columns.slice(0,4).each {|column| (self[column] += weekly.total.send(column))}
      self._columns.drop(4).each {|column| self[column] += (100.0 * weekly[column].net_per_gallon).round(2)}
    end

    def average
      self._columns.inject([]) {|array,column| array << self[column] / self.count; array}
    end
  end
=begin
  class FuelBalance < HashManager
    def initialize
      row_defs = ['beginning', 'sales', 'delivered', 'calculated', 'ending', 'difference']
      super({:})
    end

    def self.create(weeks, dispenser_net)
      instance = self.new
      instance.build(weeks, dispenser_net)
      instance
    end

    def build(weeks, dispenser_net)
      beginning_volume = weeks.first.previous_week.tank_volume
      ending_volume = weeks.last.tank_volume
      gallons_delivered = FuelDelivery.summary(weeks)
      calculated = HashManager.new({:regular => nil, :premium => nil, :diesel => nil, :total => nil})
      calculated._columns.each {|grade| calculated[grade] = beginning_volume.send(grade) +
        gallons_delivered.send(grade) - gallons_sold.send(grade)}
      difference = HashManager.new({:regular => nil, :premium => nil, :diesel => nil, :total => nil})
      difference._columns.each {|grade| difference[grade] = ending_volume.send(grade) - calculated.send(grade)}

      self.merge({:beginning => poplulate_row("Beginning Volme", beginning_volume)})
    end

    def populste_row(description, instance)
      columns = FuelDeliver::GRADES + "total"
      columns.inject({:description => description}) {|hash,column| hash[column] = instance.send(column); hash}
    end

  end
=end
end
