class FuelBalanceReport < HashManager

  attr_accessor   :first_week
  attr_accessor   :last_week

  def initialize(first_week, last_week)
    @first_week = first_week
    @last_week = last_week
    begin_volume = first_week.previous_week.tank_volume.as_json.
      select{|key, value| FuelDelivery::GRADES.include?(key)}
    end_volume = last_week.tank_volume.as_json.
      select{|key, value| FuelDelivery::GRADES.include?(key)}
    @fuel_grades = FuelDelivery::GRADES.inject({}) {|hash,grade| hash[grade] = 0.0;hash}
    @dispenser_grades = DispenserSale::GRADES.inject({}) {|hash,grade| hash[grade] = 0.0;hash}

    gallons_hash = {'tank' => {'begin' => begin_volume, 'end' => end_volume},
      'sold' => {'first' => {'date' => nil, 'fuel' => @fuel_grades.dup, 'dispenser' => @dispenser_grades.dup},
      'last' => {'date' => nil, 'fuel' => @fuel_grades.dup, 'dispenser' => @dispenser_grades.dup},
      'net' => {'fuel' => @fuel_grades.dup, 'dispenser' => @dispenser_grades.dup}},
      'deliveries' => []}

    super(gallons_hash)
  end

  def self.create(first_week, last_week)
    instance = self.new(first_week, last_week)
    instance.build
    return instance
  end

  def build
    previous_week = first_week.previous_week
    fuel_stats =  DispenserSalesTotal.net_sales_for_period(previous_week, last_week)
    self.sold.first.date = previous_week.date
    self.sold.last.date = last_week.date
    FuelDelivery::GRADES.each do |grade|
      self["sold.first.fuel.#{grade}"] = fuel_stats.sales_total_first_week["#{grade}.gallons"]
      self["sold.last.fuel.#{grade}"] = fuel_stats.sales_total_last_week["#{grade}.gallons"]
      self["sold.net.fuel.#{grade}"] = fuel_stats["#{grade}.gallons"]
    end
    dispenser_stats =  DispenserSalesTotal.net_sales_for_period(previous_week, last_week, true)
    DispenserSale::GRADES.each do |grade|
      self["sold.first.dispenser.#{grade}"] = dispenser_stats.sales_total_first_week["#{grade}.gallons"]
      self["sold.last.dispenser.#{grade}"] = dispenser_stats.sales_total_last_week["#{grade}.gallons"]
      self["sold.net.dispenser.#{grade}"] = dispenser_stats["#{grade}.gallons"]
    end
    fuel_deliveries = FuelDelivery.where(:week_id => [first_week.id..last_week.id])
    fuel_deliveries.each do |fuel_delivery|
      hash = {'date' => fuel_delivery.delivery_date, 'invoice_number' => fuel_delivery.invoice_number}
      hash['regular'] = fuel_delivery.regular_gallons.to_f
      hash['premium'] = fuel_delivery.premium_gallons.to_f
      hash['diesel'] = fuel_delivery.diesel_gallons.to_f
      self.deliveries << HashManager.new(hash)
    end
  end

  def calculated_volume
    volume = @fuel_grades.dup
    total_deliveries = self.deliveries_total
    volume.keys.each do |grade|
      volume[grade] = self["tank.begin.#{grade}"] + total_deliveries[grade] -
        self["sold.net.fuel.#{grade}"]
    end
    HashManager.new(volume)
  end

  def difference
    calculated = self.calculated_volume
    HashManager.new(@fuel_grades.keys.inject(@fuel_grades.dup) {|hash,grade|
      hash[grade] = self["tank.end.#{grade}"] - calculated[grade];hash})
  end

  def deliveries_total
    HashManager.new(@fuel_grades.keys.inject(@fuel_grades.dup) {|hash,grade|
      hash[grade] = self.deliveries.map{|d| d[grade]}.sum; hash})
  end

  def self.week(week)
    instance = FuelBalanceReport.create(week, week)
    filename = "week_of_#{week.date.to_s.gsub("-","_")}.xls"
    instance.spreadsheet(filename)
    return instance
  end

  def self.weeks(first_week, last_week)
    instance = FuelBalanceReport.create(first_week, last_week)
    filename = "weeks_#{first_week.date.to_s.gsub("-","_")}_thru_#{last_week.date.to_s.gsub("-","_")}.xls"
    instance.spreadsheet(filename)
    return instance
  end

  def self.year(tax_year = 2019)
    weeks = Week.where(:tax_year => tax_year).order(:id).select{|week| !week.tank_volume.nil?}
    instance = self.create(weeks.first, weeks.last)
    filename = "year_#{tax_year}.xls"
    instance.spreadsheet(filename)
    return instance
  end

  def spreadsheet(filename)
    book = Spreadsheet::Workbook.new
		sheet = book.create_worksheet

    sheet.column(0).width = 15
    sheet.column(1).width = 15
    sheet.column(2).width = 15
    sheet.column(3).width = 15
    sheet.column(4).width = 15

    title_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14
    header_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 12
    comment_centre_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 10
    left_justified_format = Spreadsheet::Format.new :horizontal_align => :left, :size => 12
    right_justified_format = Spreadsheet::Format.new :horizontal_align => :right, :size => 12
    currency_format = Spreadsheet::Format.new :horizontal_align => :right, :size => 12, :number_format => '##,##0.00'
    centre_justified_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 12

    row = 0
    sheet.merge_cells(row, 0, row, 4)
    sheet.row(row).default_format = title_format
    sheet.row(row).push "Dispenser Sales"
    row += 1
    sheet.row(row).default_format = header_format
    sheet.row(row).push "Date", "Regular", "Plus", "Premium", 'Diesel'
    row += 1
    sheet.row(row).set_format(0,centre_justified_format)
    sheet.row(row).push self.sold.first.date.to_s
    @dispenser_grades.keys.each_with_index do |grade, index|
      sheet.row(row).set_format(index+1,currency_format)
      sheet.row(row).push self.sold.first.dispenser.send(grade)
    end
    row += 1
    sheet.row(row).set_format(0,centre_justified_format)
    sheet.row(row).push self.sold.last.date.to_s
    @dispenser_grades.keys.each_with_index do |grade, index|
      sheet.row(row).set_format(index+1,currency_format)
      sheet.row(row).push self.sold.last.dispenser.send(grade)
    end
    row += 1
    sheet.row(row).set_format(0,centre_justified_format)
    sheet.row(row).push "Blended Net"
    @dispenser_grades.keys.each_with_index do |grade, index|
      sheet.row(row).set_format(index+1,currency_format)
      sheet.row(row).push self.sold.net.dispenser.send(grade)
    end
    row += 1
    sheet.row(row).set_format(0,centre_justified_format)
    sheet.row(row).push "Unblended Net"
    @dispenser_grades.keys.each_with_index do |grade, index|
      if grade == 'plus'
        sheet.row(row).push ""
      else
        sheet.row(row).set_format(index+1,currency_format)
        sheet.row(row).push self.sold.net.fuel.send(grade)
      end
    end
    row += 1
    sheet.merge_cells(row, 0, row, 4)
    sheet.row(row).default_format = comment_centre_format
    sheet.row(row).push "Unblended Net – Regular includes 65% of plus and premium includes 35% of plus"
    row += 2

    sheet.merge_cells(row, 0, row, 4)
    sheet.row(row).default_format = title_format
    sheet.row(row).push "Fuel Deliveries"
    row += 1
    sheet.row(row).default_format = header_format
    sheet.row(row).push "Date", "Invoice No", "Regular", "Premium", "Diesel"
    self.deliveries.each do |delivery|
      row +=1
      sheet.row(row).set_format(0,centre_justified_format)
      sheet.row(row).push delivery.date.to_s
      sheet.row(row).set_format(1,centre_justified_format)
      sheet.row(row).push delivery.invoice_number
      @fuel_grades.keys.each_with_index do |grade, index|
        sheet.row(row).set_format(index+2,currency_format)
        sheet.row(row).push delivery.send(grade)
      end
    end
    row += 1
    sheet.row(row).set_format(0,centre_justified_format)
    sheet.row(row).push "Total", ""
    @fuel_grades.keys.each_with_index do |grade, index|
      sheet.row(row).set_format(index+2,currency_format)
      sheet.row(row).push self.deliveries_total.send(grade)
    end

    row += 2

    sheet.merge_cells(row, 0, row, 4)
    sheet.row(row).default_format = title_format
    sheet.row(row).push "Actual versus calculated tank volume"
    row += 1
    sheet.merge_cells(row, 0, row, 1)
    sheet.row(row).default_format = header_format
    sheet.row(row).push "", "", "Regular", "Premium", "Diesel"
    row += 1
    sheet.merge_cells(row, 0, row, 1)
    sheet.row(row).set_format(0,left_justified_format)
    sheet.row(row).push "Volume - #{first_week.date.to_s}", ""
    @fuel_grades.keys.each_with_index do |grade, index|
      sheet.row(row).set_format(index+2,currency_format)
      sheet.row(row).push self.tank.begin.send(grade).to_f
    end
    row += 1
    sheet.merge_cells(row, 0, row, 1)
    sheet.row(row).set_format(0,left_justified_format)
    sheet.row(row).push "Gallons Sold", ""
    @fuel_grades.keys.each_with_index do |grade, index|
      sheet.row(row).set_format(index+2,currency_format)
      sheet.row(row).push self.sold.net.fuel.send(grade)
    end
    row += 1
    sheet.merge_cells(row, 0, row, 1)
    sheet.row(row).set_format(0,left_justified_format)
    sheet.row(row).push "Fuel Deliveries", ""
    @fuel_grades.keys.each_with_index do |grade, index|
      sheet.row(row).set_format(index+2,currency_format)
      sheet.row(row).push self.deliveries_total.send(grade)
    end
    row += 1
    sheet.merge_cells(row, 0, row, 1)
    sheet.row(row).set_format(0,left_justified_format)
    sheet.row(row).push "Calculated Vol - #{last_week.date.to_s}", ""
    @fuel_grades.keys.each_with_index do |grade, index|
      sheet.row(row).set_format(index+2,currency_format)
      sheet.row(row).push calculated_volume.send(grade)
    end
    row += 1
    sheet.merge_cells(row, 0, row, 1)
    sheet.row(row).set_format(0,left_justified_format)
    sheet.row(row).push "Actual Vol - #{last_week.date.to_s}", ""
    @fuel_grades.keys.each_with_index do |grade, index|
      sheet.row(row).set_format(index+2,currency_format)
      sheet.row(row).push self.tank.end.send(grade).to_f
    end
    row += 1
    sheet.merge_cells(row, 0, row, 1)
    sheet.row(row).set_format(0,left_justified_format)
    sheet.row(row).push "Difference", ""
    @fuel_grades.keys.each_with_index do |grade, index|
      sheet.row(row).set_format(index+2,currency_format)
      sheet.row(row).push self.difference.send(grade)
    end

    file_path = File.expand_path("~/Documents/jr/volume_reports/#{filename}")
    book.write file_path
  end

end
