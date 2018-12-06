class EstimatedProfit

  attr_accessor   :week
  attr_accessor   :report
  attr_accessor   :inventory
  attr_accessor   :dispenser_net

  def self.create(week)
    instance = self.new
    instance.build(week)
    return instance
  end

  def build(week)
    self.dispenser_net = DispenserSalesTotal.net_sales_for_period(week.previous_week, week, false)
    parameters = {}
    tank_volume = week.tank_volume
    FuelDelivery::GRADES.each do |grade|
      parameters[grade] = {'gallons' => self.dispenser_net.public_send(grade).gallons, 'offset' => tank_volume[grade]}
    end
    fuel_delivery = week.fuel_deliveries.order(:delivery_date).last
    self.inventory = TankInventory.create(fuel_delivery, parameters)
    report = {}
    FuelDelivery::GRADES.each do |grade|
      inventory_object = self.inventory.public_send(grade)
      dispenser_object = self.dispenser_net.public_send(grade)
      grade_hash = {:gallons => inventory_object.gallons}
      grade_hash[:retail] = dispenser_object.amount.to_f
      grade_hash[:cost] = inventory_object.amount.to_f
      grade_hash[:per_gallon_retail] = (grade_hash[:retail] / grade_hash[:gallons]).to_f
      grade_hash[:per_gallon_cost] = inventory_object.per_gallon.to_f
      grade_hash[:profit] = grade_hash[:retail] - grade_hash[:cost]
      grade_hash[:deliveries] = inventory_object.deliveries
      report[grade] = grade_hash
    end
    self.report = HashManager.new(report)
  end

  def self.week_report(week)
    report = EstimatedProfit.create(week).report
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
    sheet.row(1).push "Grade", "Gallons", "Retail", "Cost", "Profit", 'Per Gallon'

    row = nil
    (FuelDelivery::GRADES + ["total"]).each_with_index do |grade,index|
      row = index + 2
      data = report.public_send(grade)
      self.set_row_format(sheet.row(row), left_justified_format,
        right_justified_format, right_justified_format, right_justified_format,
        right_justified_format, per_gallon_format)
      sheet.row(row).push grade.titleize
      sheet.row(row).push data.gallons
      sheet.row(row).push data.retail.to_f
      sheet.row(row).push data.cost.to_f
      sheet.row(row).push data.profit.to_f
      sheet.row(row).push data.profit.to_f / data.gallons_sold
    end

    ['regular', 'premium', 'diesel'].each do |grade|
      row += 3
      sheet.merge_cells(row, 0, row, 5)
      sheet.row(row).default_format = header_format
      sheet.row(row).push "#{grade.capitalize} grade deliveries"
      row +=1
      sheet.row(row).default_format = header_format
      sheet.row(row).push "Date", "Invoice No", "Rate", "Gallons", "Applied", "Total Applied"
      deliveries = report.grade_totals.public_send(grade).deliveries
      total_applied_gallons = 0
      deliveries.each_with_index do |delivery, index|
        row += 1
        self.set_row_format(sheet.row(row), centre_justified_format,
          centre_justified_format, per_gallon_format, right_justified_format,
          right_justified_format, right_justified_format)
        total_applied_gallons += delivery.applied_gallons
        sheet.row(row).push delivery.date.to_s, delivery.invoice_number,
          delivery.per_gallon, delivery.total_gallons,
          delivery.applied_gallons, total_applied_gallons
      end
    end

    file_path = File.expand_path("~/Documents/jr/fuel_reports_test/week_of_#{week.date.to_s.gsub("-","_")}.xls")
    book.write file_path
    return report
  end

  def self.set_row_format(row, format0, format1, format2, format3, format4, format5)
    row.set_format(0,format0)
    row.set_format(1,format1)
    row.set_format(2,format2)
    row.set_format(3,format3)
    row.set_format(4,format4)
    row.set_format(5,format5)
  end

  class WeekProfit

    attr_accessor   :report
    attr_accessor   :inventory
    attr_accessor   :dispenser_net

    def self.create(week)
      instance = self.new
      report = instance.build(week)
      return instance
    end

    def build(week)
      self.dispenser_net = DispenserSalesTotal.net_sales_for_period(week.previous_week, week, false)
      parameters = {}
      tank_volume = week.tank_volume
      FuelDelivery::GRADES.each do |grade|
        parameters[grade] = {'gallons' => self.dispenser_net.public_send(grade).gallons, 'offset' => tank_volume[grade]}
      end
      fuel_delivery = week.fuel_deliveries.order(:delivery_date).last
      self.inventory = TankInventory.create(fuel_delivery, parameters)
      #self.inventory = tank_volume.inventory(true)
      report = {}
      FuelDelivery::GRADES.each do |grade|
        inventory_object = self.inventory.public_send(grade)
        dispenser_object = self.dispenser_net.public_send(grade)
        grade_hash = {:gallons => inventory_object.gallons}
        grade_hash[:retail] = dispenser_object.amount.to_f
        grade_hash[:cost] = inventory_object.amount.to_f
        grade_hash[:per_gallon_retail] = (grade_hash[:retail] / grade_hash[:gallons]).to_f
        grade_hash[:per_gallon_cost] = inventory_object.per_gallon.to_f
        grade_hash[:profit] = grade_hash[:retail] - grade_hash[:cost]
        grade_hash[:deliveries] = inventory_object.deliveries
        report[grade] = grade_hash
      end
      self.report = HashManager.new(report)
    end

  end
end
