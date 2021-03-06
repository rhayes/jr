class WeekEstimatedProfit < HashManager

  attr_accessor   :week
  attr_accessor   :grade_totals
  attr_accessor   :profit

  FUEL_GRADES = ['regular', 'premium', 'diesel']

  def initialize(week)
    @week = week
    hash = {}
    FUEL_GRADES.each do |fuel_grade|
      grade_info = {'gallons' => 0.0, 'per_gallon' => 0.0, 'deliveries' => []}
      hash[fuel_grade] = grade_info
      grade_hash = {}
      (FUEL_GRADES + ['total']).each do |grade|
        grade_hash[grade] = {'gallons_sold' => 0, 'estimated_per_gallon' => 0.0,
          'net_per_gallon' => 0.0, 'retail' => Money.new(0),
          'cost' => Money.new(0), 'net' => 0.0}
      end
      @profit = HashManager.new(grade_hash)
    end
    super(hash)
  end

  def self.year_to_date_report(tax_year = 2019, week_ids = nil)
    weeks = nil
    if week_ids.nil?
      ids = Week.where(:tax_year => tax_year).pluck(:id)
      week_ids = DispenserSale.where(:week_id => ids).order(:week_id).pluck(:week_id).uniq
      #dispenser_sales = DispenserSale.where(:week_id => ids).order(:week_id)
      #week_ids = dispenser_sales.first.week_id..dispenser_sales.last.week_id
      weeks = Week.where(:id => week_ids)
    else
      weeks = Week.where(:id => week_ids)
    end
    reports = []
    weeks.each {|week| reports << WeekEstimatedProfit.create(week)}

    book = Spreadsheet::Workbook.new
		sheet = book.create_worksheet
    sheet.column(0).width = 15
    sheet.column(1).width = 15
    sheet.column(2).width = 18
    sheet.column(3).width = 18
    sheet.column(4).width = 15
    sheet.column(5).width = 10
    sheet.column(6).width = 12
    sheet.column(7).width = 12
    sheet.column(8).width = 12

		title_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 16
		header_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14
    left_justified_format = Spreadsheet::Format.new :horizontal_align => :left, :size => 14
    right_justified_format = Spreadsheet::Format.new :horizontal_align => :right, :size => 14, :number_format => '#,###,##0.00'
    per_gallon_format = Spreadsheet::Format.new :horizontal_align => :right, :size => 14, :number_format => '##0.00'
    centre_justified_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14

    sheet.merge_cells(0, 0, 0, 8)
    sheet.row(0).default_format = title_format
    sheet.row(0).push "#{tax_year} Estimated Fuel Profit"
    sheet.merge_cells(1, 0, 1, 4)
    sheet.merge_cells(1, 5, 1, 8)
    sheet.row(1).default_format = header_format
    sheet.row(1).push "", "", "", "", "", "Per Gallon"
    sheet.row(2).default_format = header_format
    sheet.row(2).push "Week", "Gallons", "Retail", "Cost", "Net", 'Overall', 'Regular', 'Premium', "Diesel"
    total_retail = total_cost = total_net = 0.0
    total_regular_gallons = total_premium_gallons = total_diesel_gallons = 0.0
    total_regular_net_profit = total_premium_net_profit = total_diesel_net_profit = 0.0
    total_gallons = row = 0
    reports.each_with_index do |report,index|
      data = report.profit.total
      row = index + 3
      self.set_row_format(sheet.row(row), [centre_justified_format,
        centre_justified_format, right_justified_format, right_justified_format,
        right_justified_format, per_gallon_format, per_gallon_format,
        per_gallon_format, per_gallon_format])
      sheet.row(row).push report.week.date.to_s
      sheet.row(row).push data.gallons_sold
      sheet.row(row).push data.retail.to_f
      sheet.row(row).push data.cost.to_f
      sheet.row(row).push data.net.to_f
      sheet.row(row).push (100.0 * report.profit.total.net_per_gallon.to_f).round(2)
      sheet.row(row).push (100.0 * report.profit.regular.net_per_gallon.to_f).round(2)
      sheet.row(row).push (100.0 * report.profit.premium.net_per_gallon.to_f).round(2)
      sheet.row(row).push (100.0 * report.profit.diesel.net_per_gallon.to_f).round(2)
      #sheet.row(row).push data.estimated_per_gallon.to_f
      total_gallons += data.gallons_sold
      total_retail += data.retail
      total_cost += data.cost
      total_net += data.net
      total_regular_gallons += report.profit.regular.gallons_sold
      total_premium_gallons += report.profit.premium.gallons_sold
      total_diesel_gallons += report.profit.diesel.gallons_sold
      total_regular_net_profit += report.profit.regular.net
      total_premium_net_profit += report.profit.premium.net
      total_diesel_net_profit += report.profit.diesel.net
    end

    row += 2
    self.set_row_format(sheet.row(row), [centre_justified_format,
      centre_justified_format, right_justified_format, right_justified_format,
      right_justified_format, per_gallon_format])
    sheet.row(row).push "TOTAL"
    sheet.row(row).push total_gallons
    sheet.row(row).push total_retail.to_f
    sheet.row(row).push total_cost.to_f
    sheet.row(row).push total_net.to_f

    number_weeks = reports.count
    row += 2
    self.set_row_format(sheet.row(row), [centre_justified_format,
      centre_justified_format, right_justified_format, right_justified_format,
      right_justified_format, per_gallon_format, per_gallon_format,
      per_gallon_format, per_gallon_format])
    sheet.row(row).push "AVERAGE"
    sheet.row(row).push (total_gallons.to_f / number_weeks).round.to_i
    sheet.row(row).push total_retail.to_f / number_weeks
    sheet.row(row).push total_cost.to_f / number_weeks
    sheet.row(row).push total_net.to_f / number_weeks
    sheet.row(row).push (100.0 * (total_net.to_f / total_gallons.to_f)).round(2)
    sheet.row(row).push (100.0 * (total_regular_net_profit.to_f / total_regular_gallons.to_f)).round(2)
    sheet.row(row).push (100.0 * (total_premium_net_profit.to_f / total_premium_gallons.to_f)).round(2)
    sheet.row(row).push (100.0 * (total_diesel_net_profit.to_f / total_diesel_gallons.to_f)).round(2)

    last_week = reports.last.week
    file_path = File.expand_path("~/Documents/jr/fuel_reports/#{last_week.date.to_s.gsub("-","_")}.xls")
    book.write file_path
    return reports
  end

  def self.week_report(week)
    report = WeekEstimatedProfit.create(week)
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
    (FUEL_GRADES + ["total"]).each_with_index do |grade,index|
      row = index + 2
      data = report.profit.public_send(grade)
      self.set_row_format(sheet.row(row), [left_justified_format,
        right_justified_format, right_justified_format, right_justified_format,
        right_justified_format, per_gallon_format])
      sheet.row(row).push grade.titleize
      sheet.row(row).push data.gallons_sold
      sheet.row(row).push data.retail.to_f
      sheet.row(row).push data.cost.to_f
      sheet.row(row).push data.net.to_f
      sheet.row(row).push data.net.to_f / data.gallons_sold
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
        self.set_row_format(sheet.row(row), [centre_justified_format,
          centre_justified_format, per_gallon_format, right_justified_format,
          right_justified_format, right_justified_format])
        total_applied_gallons += delivery.applied_gallons
        sheet.row(row).push delivery.date.to_s, delivery.invoice_number,
          delivery.per_gallon, delivery.total_gallons,
          delivery.applied_gallons, total_applied_gallons
      end
    end

    file_path = File.expand_path("~/Documents/jr/fuel_reports/week_of_#{week.date.to_s.gsub("-","_")}.xls")
    book.write file_path
    return report
  end

  def self.set_row_format(row, formats)
    formats.each_with_index {|format,index| row.set_format(index,format)}
  end

  def self.create(week)
    puts "Week ID:  #{week.id}"
    instance = self.new(week)
    instance.grade_totals = instance.build
    return instance
  end

  def build
    net_sales = DispenserSalesTotal.net_sales_for_period(week.previous_week, week, false)
    grade_totals = GradeTotal.new(self.week, net_sales)
    grade_totals.build_grades
    total_profit_row = self.profit.total
    FUEL_GRADES.each do |grade|
      grade_profit_row = self.profit.public_send(grade)
      grade_totals_row = grade_totals.retrieve_by_grade(grade)

      grade_profit_row.gallons_sold = grade_totals_row.gallons_sold
      total_profit_row.gallons_sold += grade_profit_row.gallons_sold

      grade_profit_row.estimated_per_gallon = grade_totals_row.estimated_per_gallon.round(4)

      grade_profit_row.retail = grade_totals_row.amount
      total_profit_row.retail += grade_profit_row.retail

      cost = grade_profit_row.estimated_per_gallon * grade_profit_row.gallons_sold
      grade_profit_row.cost = Money.new(100 * cost)
      total_profit_row.cost += grade_profit_row.cost

      grade_profit_row.net = grade_profit_row.retail - grade_profit_row.cost
      grade_profit_row.net_per_gallon = (grade_profit_row.net.to_f / grade_profit_row.gallons_sold.to_f).round(4)
      total_profit_row.net += grade_profit_row.net
    end
    total_profit_row.estimated_per_gallon =
      (total_profit_row.cost.to_f / total_profit_row.gallons_sold).round(4)
    total_profit_row.net_per_gallon = (total_profit_row.net.to_f / total_profit_row.gallons_sold.to_f).round(4)
    return grade_totals
  end

  class GradeTotal < HashManager

    attr_accessor   :week
    attr_accessor   :net_profit

    def initialize(week, net_sales)
      @week = week
      regular_hash = {'name' => 'regular', 'amount' => net_sales.regular.amount,
        'gallons_sold' => net_sales.regular.gallons.round(2).to_i,
        'estimated_per_gallon' => 0.0, 'net_profit' => 0.0, 'deliveries' => []}
      premium_hash = {'name' => 'premium', 'amount' => net_sales.premium.amount,
        'gallons_sold' => net_sales.premium.gallons.round(2).to_i,
        'estimated_per_gallon' => 0.0, 'net_profit' => 0.0, 'deliveries' => []}
      diesel_hash = {'name' => 'diesel', 'amount' => net_sales.diesel.amount,
        'gallons_sold' => net_sales.diesel.gallons.round(2).to_i,
        'estimated_per_gallon' => 0.0, 'net_profit' => 0.0, 'deliveries' => []}
      hash = {'regular' => Grade.new('regular',regular_hash),
        'premium' => Grade.new('premium',premium_hash),
        'diesel' => Grade.new('diesel',diesel_hash),}
      super(hash)
    end

    def retrieve_by_grade(grade)
      grade_rows = self.to_hash.keys.map{|key| self.public_send(key)}
      return grade_rows.select{|grade_row| grade_row.name == grade}.first
    end

    def delivery_gallons_column(grade)
      return self.public_send(grade).delivery_gallons_column
    end

    def delivery_per_gallon_column(grade)
      return self.public_send(grade).delivery_per_gallon_column
    end

    def build_grades
      grades = ['regular', 'premium', 'diesel']
      grades.each {|grade| self.public_send(grade).build(self.week)}
      self.net_profit = grades.inject(0.0) {|total, grade|
        total += self.public_send(grade).net_profit; total}
    end

    class Grade < HashManager

      attr_accessor   :grade

      def initialize(grade, hash)
        @grade = grade
        super(hash)
      end

      def delivered_gallons_column
        return self.name + "_gallons"
      end

      def delivered_per_gallon_column
        return self.name + "_per_gallon"
      end

      def build(week)
        puts "Grade:  #{self.grade}"
        current_volume = week.tank_volume[self.grade]
        fuel_deliveries = FuelDelivery.where("delivery_date <= ?",week.date).
          where("#{delivered_gallons_column} > 0").order("delivery_date desc")
        accumulated_gallons = 0
        fuel_deliveries.each do |fuel_delivery|
          delivered_gallons = fuel_delivery[delivered_gallons_column]
          if current_volume >= delivered_gallons
            current_volume -= delivered_gallons
            self.deliveries << HashManager.new({'id' => fuel_delivery.id,
              'date' => fuel_delivery.delivery_date,
              'invoice_number' => fuel_delivery.invoice_number,
              'per_gallon' => fuel_delivery[delivered_per_gallon_column].to_f,
              'total_gallons' => fuel_delivery[delivered_gallons_column],
              'applied_gallons' => 0})
            next
          else
            applied_gallons = remaining_gallons = delivered_gallons - current_volume
            accumulated_gallons += remaining_gallons
            if accumulated_gallons > self.gallons_sold
              applied_gallons -= (accumulated_gallons - self.gallons_sold)
              accumulated_gallons -= (remaining_gallons - applied_gallons)
            end
            current_volume -= (delivered_gallons - applied_gallons) unless current_volume == 0
          end
          self.deliveries << HashManager.new({'id' => fuel_delivery.id,
            'date' => fuel_delivery.delivery_date,
            'invoice_number' => fuel_delivery.invoice_number,
            'per_gallon' => fuel_delivery[delivered_per_gallon_column].to_f,
            'total_gallons' => fuel_delivery[delivered_gallons_column],
            'applied_gallons' => applied_gallons})
          break if accumulated_gallons == self.gallons_sold
        end
        self.estimated_per_gallon = (self.deliveries.map{|d|
          d.applied_gallons * d.per_gallon}.sum / self.gallons_sold) + 0.07
        self.net_profit = self.amount.to_f - (self.estimated_per_gallon * self.gallons_sold)
      end

    end
  end

end
