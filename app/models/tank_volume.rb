class TankVolume < ActiveRecord::Base

  belongs_to    :week

  def self.to_hash_array
    array = []
    self.all.each do |volume|
      hash = {:parent => {:id => volume.id, :week_id => volume.week_id}, :children => []}
      ['regular', 'premium', 'diesel'].each do |grade_name|
        hash[:children] << {:grade_name => grade_name, :tank_volume_id => nil,
          :grade_id => nil, :gallons => volume.send(grade_name)}
      end
      array << hash
    end
    array
    #self.all.as_json
  end

  def self.to_json_file
    json = JSON.pretty_generate(to_hash_array)
    file = File.open(File.expand_path("~/Documents/tank_volumes.json"), 'w') {|file| file.write(json.force_encoding("UTF-8"))}
  end

  def self.xxx(first_date, last_date)
    raise "#{last_date.to_s} is before #{first_date.to_s}" if last_date <= first_date
    first_week = Week.where(:date => first_date).first
    raise "No match for #{first_date.to_s}" if first_week.nil?
    last_week = Week.where(:date => last_date).first
    raise "No match for #{last_date.to_s}" if last_week.nil?
    date_range = first_date+1.day..last_date
    deliveries = FuelDelivery.where(:delivery_date => date_range)
    #dispenser_sales = DispenserSale
  end

  def total
    return regular + premium + diesel
  end

  def grade_array
    grades = FuelDelivery::GRADES + ['total']
    grades.inject([]) {|array,grade| array << self.send(grade); array}
  end

  def inventory(offset = false)
    parameters = {}
    FuelDelivery::GRADES.each do |grade|
      offset_gallons = offset ? self[grade] : 0.0
      parameters[grade] = {'gallons' => self[grade].to_f, 'offset' => offset_gallons}
    end
    fuel_delivery = self.week.fuel_deliveries.order(:delivery_date).last
    return TankInventory.create(fuel_delivery, parameters)
  end

  def calculated_versus_actual
    last_week = self.week
    first_week = last_week.previous_week
    self.calculated_versus_actual_report(first_week, last_week)
  end

  def calculated_versus_actual_report(first_week, last_week)
    net_sales = DispenserSalesTotal.net_sales_for_period(first_week, last_week)
    grades = ['regular', 'premium', 'diesel']
    hash = grades.inject({}) {|hash,grade|
      hash[grade] = net_sales.sales_total_first_week.send(grade); hash}
    unblended_first_week = HashManager.new(hash)
    hash = grades.inject({}) {|hash,grade|
      hash[grade] = net_sales.sales_total_last_week.send(grade); hash}
    unblended_last_week = HashManager.new(hash)

    blended_grades = ['regular', 'plus', 'premium', 'diesel']
    blended_first_week = DispenserSalesTotal.new(first_week, true)
    blended_last_week = DispenserSalesTotal.new(last_week, true)

    net_hash = blended_grades.inject({}) {
      |hash,grade| hash[grade] = (blended_last_week.send(grade).gallons -
      blended_first_week.send(grade).gallons).round(2);hash}
    net_blended =  HashManager.new(net_hash)

    weeks = Week.where("date > ? and date <= ?", first_week.date, last_week.date)
    fuel_deliveries = FuelDelivery.where(:week_id => weeks.map(&:id))
    #fuel_deliveries = last_week.fuel_deliveries
    fuel_hash = grades.inject({}) {|hash, grade|
      hash[grade] = fuel_deliveries.map{|d| d[grade + "_gallons"].to_f}.sum;hash}
    fuel_deliveries_total = HashManager.new(fuel_hash)

    calculated_hash = grades.inject({}) {|hash,grade| hash[grade] =
      first_week.tank_volume.send(grade).to_f + fuel_deliveries_total.send(grade) -
      net_sales.send(grade).gallons; hash}
    calculated_volume = HashManager.new(calculated_hash)

    difference_hash = grades.inject({}) {|hash,grade|
      hash[grade] = self.send(grade) - calculated_volume.send(grade); hash}
    difference_volume = HashManager.new(difference_hash)

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
    sheet.row(row).push first_week.date.to_s
    blended_grades.each_with_index do |grade, index|
      sheet.row(row).set_format(index+1,currency_format)
      sheet.row(row).push blended_first_week.send(grade).gallons
    end
    row += 1
    sheet.row(row).set_format(0,centre_justified_format)
    sheet.row(row).push last_week.date.to_s
    blended_grades.each_with_index do |grade, index|
      sheet.row(row).set_format(index+1,currency_format)
      sheet.row(row).push blended_last_week.send(grade).gallons
    end
    row += 1
    sheet.row(row).set_format(0,centre_justified_format)
    sheet.row(row).push "Blended Net"
    blended_grades.each_with_index do |grade, index|
      sheet.row(row).set_format(index+1,currency_format)
      sheet.row(row).push net_blended.send(grade)
    end
    row += 1
    sheet.row(row).set_format(0,centre_justified_format)
    sheet.row(row).push "Unblended Net"
    blended_grades.each_with_index do |grade, index|
      if grade == 'plus'
        sheet.row(row).push ""
      else
        sheet.row(row).set_format(index+1,currency_format)
        sheet.row(row).push net_sales.send(grade).gallons
      end
    end
    row += 1
    sheet.merge_cells(row, 0, row, 4)
    sheet.row(row).default_format = comment_centre_format
    sheet.row(row).push "Unblended Net – Regular includes 65% of plus and premium includes 35% of plus"
    row += 2
=begin
    sheet.merge_cells(row, 0, row, 4)
    sheet.row(row).default_format = title_format
    sheet.row(row).push "Sales by Fuel Grade"
    row += 1
    sheet.row(row).default_format = header_format
    sheet.row(row).push "Date", "Regular", "Premium", 'Diesel'
    row += 1
    sheet.row(row).set_format(0,centre_justified_format)
    sheet.row(row).push first_week.date.to_s
    grades.each_with_index do |grade, index|
      sheet.row(row).set_format(index+1,currency_format)
      sheet.row(row).push unblended_first_week.send(grade).gallons
    end
    row += 1
    sheet.row(row).set_format(0,centre_justified_format)
    sheet.row(row).push last_week.date.to_s
    grades.each_with_index do |grade, index|
      sheet.row(row).set_format(index+1,currency_format)
      sheet.row(row).push unblended_last_week.send(grade).gallons
    end
    row += 1
    sheet.row(row).set_format(0,centre_justified_format)
    sheet.row(row).push "Net Volume"
    grades.each_with_index do |grade, index|
      sheet.row(row).set_format(index+1,currency_format)
      sheet.row(row).push net_sales.send(grade).gallons
    end

    row += 2
=end
    sheet.merge_cells(row, 0, row, 4)
    sheet.row(row).default_format = title_format
    sheet.row(row).push "Fuel Deliveries"
    row += 1
    sheet.row(row).default_format = header_format
    sheet.row(row).push "Date", "Invoice No", "Regular", "Premium", "Diesel"
    fuel_deliveries.each do |delivery|
      row +=1
      sheet.row(row).set_format(0,centre_justified_format)
      sheet.row(row).push delivery.delivery_date.to_s
      sheet.row(row).set_format(1,centre_justified_format)
      sheet.row(row).push delivery.invoice_number
      grades.each_with_index do |grade, index|
        sheet.row(row).set_format(index+2,currency_format)
        sheet.row(row).push delivery.send(grade + "_gallons").to_f
      end
    end
    row += 1
    sheet.row(row).set_format(0,centre_justified_format)
    sheet.row(row).push "Total", ""
    grades.each_with_index do |grade, index|
      sheet.row(row).set_format(index+2,currency_format)
      sheet.row(row).push fuel_deliveries_total.send(grade)
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
    grades.each_with_index do |grade, index|
      sheet.row(row).set_format(index+2,currency_format)
      sheet.row(row).push first_week.tank_volume.send(grade).to_f
    end
    row += 1
    sheet.merge_cells(row, 0, row, 1)
    sheet.row(row).set_format(0,left_justified_format)
    sheet.row(row).push "Gallons Sold", ""
    grades.each_with_index do |grade, index|
      sheet.row(row).set_format(index+2,currency_format)
      sheet.row(row).push net_sales.send(grade).gallons
    end
    row += 1
    sheet.merge_cells(row, 0, row, 1)
    sheet.row(row).set_format(0,left_justified_format)
    sheet.row(row).push "Fuel Deliveries", ""
    grades.each_with_index do |grade, index|
      sheet.row(row).set_format(index+2,currency_format)
      sheet.row(row).push fuel_deliveries_total.send(grade)
    end
    row += 1
    sheet.merge_cells(row, 0, row, 1)
    sheet.row(row).set_format(0,left_justified_format)
    sheet.row(row).push "Calculated Vol - #{last_week.date.to_s}", ""
    grades.each_with_index do |grade, index|
      sheet.row(row).set_format(index+2,currency_format)
      sheet.row(row).push calculated_volume.send(grade)
    end
    row += 1
    sheet.merge_cells(row, 0, row, 1)
    sheet.row(row).set_format(0,left_justified_format)
    sheet.row(row).push "Actual Vol - #{last_week.date.to_s}", ""
    grades.each_with_index do |grade, index|
      sheet.row(row).set_format(index+2,currency_format)
      sheet.row(row).push self.send(grade)
    end
    row += 1
    sheet.merge_cells(row, 0, row, 1)
    sheet.row(row).set_format(0,left_justified_format)
    sheet.row(row).push "Difference", ""
    grades.each_with_index do |grade, index|
      sheet.row(row).set_format(index+2,currency_format)
      sheet.row(row).push difference_volume.send(grade)
    end

    file_path = File.expand_path("~/Documents/jr/volume_reports/calulated_versus_actual_#{week.date.to_s.gsub("-","_")}.xls")
    book.write file_path

    return net_blended
  end
end
