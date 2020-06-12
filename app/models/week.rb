class Week < ApplicationRecord
  include WeeklyReport

  has_one     :tank_volume
  has_many    :fuel_deliveries
  has_many    :dispenser_sales
  has_many    :transactions

  scope		:tax_year, lambda{|year| where(:tax_year => year)}
  scope   :week_number, lambda{|no,year| where(:number => no, :tax_year => year)}

  def self.add_week(tax_year = 2020)
    last_week = Week.last
    new_week = Week.new
    new_week.number = last_week.number < 52 ? last_week.number + 1 : 1
    new_week.date = last_week.date + 1.week
    new_week.tax_year = tax_year
    new_week.save!
    return new_week
  end

  def init_dispenser_sales
    return unless self.dispenser_sales.empty?
    puts "Not Empty"
    [1,2,3,4,5,6].each do |number|
      sale = self.dispenser_sales.new
      sale.number = number
      sale.save!
    end
  end

  def self.to_hash_array
    self.all.as_json
  end

  def self.to_json_file
    json = JSON.pretty_generate(self.all.as_json)
    file = File.open(File.expand_path("~/Documents/weeks.json"), 'w') {|file| file.write(json.force_encoding("UTF-8"))}
  end

  def add_commission(amount, date, check_number, override = false)
    unless override || Transaction.fuel_commission.where(:week_id => self.id).first.nil?
      raise "Commssion already exits!"
    end
    Transaction.create(:date => date, :check_number => check_number, :amount_cents => 100 * amount,
      :category => 'fuel_commission', :week_id => self.id)
    Transaction.calculate_balances
  end

  def value_of_inventory
    return TankInventory.value_of_inventory(self)
  end

  def previous_week
    return Week.where("id < ?",self.id).order("id desc").first
  end

  def date_range
    return self.date-6.days..self.date
  end

  def dispenser_report
    self.create_dispenser_report(self)
  end

  def fuel_profit_report
    return WeekEstimatedProfit.week_report(self)
  end

  def fuel_profit_year_to_date_report
    weeks = Week.tax_year(self.tax_year).where("id <= ?",self.id).order(:id)
    return WeekEstimatedProfit.year_to_date_report(self.tax_year, weeks)
  end

  def fuel_balance_report
    FuelBalanceReport.week(self)
  end

  def fuel_balance_year_to_date_report
    FuelBalanceReport.year(self.tax_year)
  end

  def net_fuel_profit
    sale = Transaction.fuel_sale.week(self.id).first
    sales = sale.amount.to_f.round(2)
    sales -= 900.0 if sale.includes_lease
    #sales = Transaction.fuel_sale.week(self.id).first.amount.to_f.round(2)
    #transaction = Transaction.fuel_commission.week(self.id).first
    #commission = transaction.nil? ? 0.0 : transaction.amount.to_f.round(2)
    commission = Transaction.fuel_commission.week(self.id).map{|t| t.amount.to_f}.sum.round(2)
    inventory_before = self.previous_week.value_of_inventory.amount.round(2)
    inventory_after = self.value_of_inventory.amount.round(2)
    fuel_cost = self.fuel_deliveries.map{|fd| fd.total}.sum.to_f.round(2)
    net = (sales + inventory_after - commission - fuel_cost - inventory_before).round(2)
    return net, sales, commission, inventory_before, inventory_after, fuel_cost
  end

  def net_fuel_profit_year_to_date(weeks = nil)
    weeks = Week.tax_year(self.tax_year).where("id <= ?", self.id).order(:id) if weeks.nil?
    week_ids = weeks.map(&:id)
    puts "Sales:  #{Transaction.fuel_sale.week(week_ids).count}"
    sales = Transaction.fuel_sale.week(week_ids).map{|s| s.amount}.sum.to_f.round(2)
    #lease_payments =
    puts "Commissions: #{Transaction.fuel_commission.week(week_ids).count}"
    commission = Transaction.fuel_commission.week(week_ids).map{|s| s.amount}.sum.to_f.round(2)
    inventory_before = weeks.first.previous_week.value_of_inventory.amount.round(2)
    inventory_after = weeks.last.value_of_inventory.amount.round(2)
    puts "Fuel_cost:  #{Transaction.fuel_cost.week(week_ids).count}"
    fuel_cost = Transaction.fuel_cost.week(week_ids).map{|s| s.amount}.sum.to_f.round(2)
    net = (sales + inventory_after - commission - fuel_cost - inventory_before).round(2)
    return net, sales, commission, inventory_before, inventory_after, fuel_cost
  end

  def self.migrate_commissions(save_results = false, tax_year = 2019)
    weeks = Week.tax_year(tax_year).order("number desc")
    #commissions = Transaction.fuel_commission.order(:date).to_a
    array = []
    weeks.each do |week|
      net_sales = DispenserSale.net_for_week(week)
      ideal_amount = (0.06 * net_sales.total_gallons).round(2)
      range_amount = ideal_amount - 5.0 .. ideal_amount + 5.0
      commissions = Transaction.fuel_commission.where(:week_id => nil).
        where("date > ?",week.date).order(:date).limit(3)
      commission = nil
      puts "Week:  #{week.id}"
      puts "\t TEMP: Range:  #{range_amount}"
      commissions.each do |comm|
        puts "\t Commission:  #{comm.amount.to_f}"
        if range_amount.include?(comm.amount.to_f)
          commission = comm
          puts "\t MATCHED"
          break
        end
      end
      #commission = commissions.select{|c| c.date > week.date && range_amount.include?(c.amount.to_f)}.first
      if commission.nil?
        transaction_id = transaction_date = amount = nil
      else
        transaction_id = commission.id
        transaction_date = commission.date.to_s
        amount = commission.amount.to_f.round(2)
        #commissions.pop
      end
      commission.update_column(:week_id, week.id) if save_results && !transaction_id.nil?
      array << {:week_id => week.id, :week_date => week.date, :transaction_id => transaction_id,
        :transaction_date => transaction_date, :amount => amount}
    end
    array
  end

  def post_data
    if id >= 180
      PostWeeklyData.perform(self)
      return
    end
    lines = File.readlines(File.expand_path("~/Documents/jr_reports/scripts/week_#{self.id}.txt"))
    str = ""
    objects = []
    lines.dup.each do |line|
      line = line.strip
      next if line.size == 0
      if line[-1] == '='
        str += line.gsub!(/\=$/,'').strip
      else
      objects << PostingObject.new(JSON.parse(str + line.strip))
        str = ""
      end
    end
    objects.each do |object|
      if object.is_fuel_delivery?
        fd = FuelDelivery.where(:invoice_number => object.invoice_number,
          :week_id => self.id, :delivery_date => object.date).first_or_create!
        fd.monthly_tank_charge = object.monthly_tank_charge
        object.grades.each do |grade_object|
          fd[grade_object.grade + "_gallons"] = grade_object.gallons
          fd[grade_object.grade + "_per_gallon"] = grade_object.per_gallon
        end
        fd.save!
      elsif object.is_tank_volume?
        volume = TankVolume.where(:week_id => self.id).first_or_create!
        object.grades.each do |grade_object|
          volume[grade_object.grade] = grade_object.gallons
        end
        volume.save!
      elsif object.is_dispenser_sales?
        sales = DispenserSale.where(:week_id => self.id, :number => object.number).first_or_create!
        object.grades.each do |grade_object|
          grade = grade_object.grade
          sales[grade + "_cents"] = grade_object.dollars.to_money.cents
          sales[grade + "_volume"] = grade_object.gallons
          sales[grade + "_dollars_adjustment"] = -grade_object.dollars_adjustment
          sales[grade + "_volume_adjustment"] = -grade_object.gallons_adjustment
          sales.save!
          #dsg.gallons = grade_object.gallons
          #dsg.dollars_cents = grade_object.dollars.to_money.cents
          #dsg.gallons_adjustment = grade_object.gallons_adjustment
          #dsg.dollars_adjustment_cents = grade_object.dollars_adjustment.to_money.cents
          #dsg.save!
        end
      end
    end
    objects
  end

  def self.migrate_deposits(save_results = false, tax_year = 2019)
    weeks = Week.tax_year(tax_year).order("id desc")
    #commissions = Transaction.fuel_commission.order(:date).to_a
    array = []
    matches = 0
    weeks.each do |week|
      net_sales = DispenserSale.net_for_week(week)
      sales = net_sales.total_dollars
      ranges_sales = sales - 5.0 .. sales + 5.0
      deposits = Transaction.fuel_sale.where("date > ?",week.date).order(:date).limit(3).
        select{|s| s.week_id.nil?}
      deposit = nil
      puts "Week:  #{week.id}"
      puts "\t TEMP: Range:  #{ranges_sales}"
      includes_deposit = false
      deposits.each do |comm|
        puts "\t Deposit:  #{comm.amount.to_f}"
        if ranges_sales.include?(comm.amount.to_f)
          deposit = comm
          puts "\t MATCHED"
          break
        elsif ranges_sales.include?(comm.amount.to_f - 900.0)
          deposit = comm
          puts "\t MATCHED WITH DEPOSIT"
          includes_deposit = true
          break
        end
      end
      #deposit = deposits.select{|c| c.date > week.date && ranges_sales.include?(c.amount.to_f)}.first
      if deposit.nil?
        transaction_id = transaction_date = amount = nil
      else
        matches += 1
        transaction_id = deposit.id
        transaction_date = deposit.date.to_s
        amount = deposit.amount.to_f.round(2)
        #deposits.pop
      end
      deposit.update_attributes(:week_id => week.id, :includes_deposit => includes_deposit) if save_results && !transaction_id.nil?
      array << {:week_id => week.id, :week_date => week.date, :transaction_id => transaction_id,
        :transaction_date => transaction_date, :amount => amount}
    end
    puts "MATCHES:  #{matches}"
    array
  end

  def self.find_deposits(date_range)
    weeks = Week.where(:date => date_range)
    weeks.each do |week|
      deposit = week.find_deposit
      deposit_id = deposit.nil? ? nil : deposit.id
      puts "Date:  #{week.date.to_s}  --  deposit_id:  #{deposit_id}"
    end
  end

  def dispenser_sales_with_offset
    names = DispenserSale.columns.map{|c| c.name}.
      select{|c| c.include?("_cents") || c.include?("_volume")}.
      delete_if{|c| c.include?("_adjustment")}.sort
    translation = names.inject({}) {|hash,name| hash[name] = name.gsub("_volume","_gallons");hash}
    column_names = names.inject([]) {|array,name| array << name.gsub("_volume","_gallons");array}
    sales = self.dispenser_sales.order(:number)
    results = []
    sales.each do |sale|
      object_hash = {}
      sales_hash = sale.as_json.each do |key,value|
        object_hash[key] = value.kind_of?(BigDecimal) ? value.to_f : value
        unless (column = translation[key]).nil?
          offset = DispenserOffset.get_offset(sale.number, column, self.date)
          puts "Offset:  #{offset}"
          if offset.kind_of?(Money)
            puts "\t#{object_hash}\n\n"
            object_hash[key] += 100 * offset.to_i
          else
            object_hash[key] += offset
          end
        end
        next
        if translation[key].nil?
          object_hash[key] = value
        else
          column = translation[key]
          offset = DispenserOffset.get_offset(sale.number, column, self.date)
          puts "#{sale.number}  --  #{column}  --  #{value}  --  #{offset}"
          object_hash[column] = value + offset
        end
      end
      results << HashManager.new(object_hash)
    end
    return results
  end

  def dispenser_report_beta
    DispenserReportSpreadsheet.create(self)
  end

  def fuel_profit_beta
    FuelProfitSpreadsheet.create_weekly_report(self)
  end

  def fuel_profit_detailed_annual_beta
    FuelProfitSpreadsheet.create_detailed_annual_report(self)
  end

  def fuel_profit_summary_annual_beta
    FuelProfitSpreadsheet.create_summary_annual_report(self)
  end

=begin
  def dispenser_totals
    dispenser_sales = self.dispenser_sales
    regular_volume = dispenser_sales.map(&:regular_volume).sum
    plus_volume = dispenser_sales.map(&:plus_volume).sum
    premium_volume = dispenser_sales.map(&:premium_volume).sum
    diesel_volume = dispenser_sales.map(&:diesel_volume).sum
    regular_cents = dispenser_sales.map(&:regular_cents).sum
    plus_cents = dispenser_sales.map(&:plus_cents).sum
    premium_cents = dispenser_sales.map(&:premium_cents).sum
    diesel_cents = dispenser_sales.map(&:diesel_cents).sum
    return regular_cents, plus_cents, premium_cents, diesel_cents,
      regular_volume, plus_volume, premium_volume, diesel_volume
  end

  def sales_to_date
    dispenser_rows = self.dispenser_sales
    regular_sales = dispenser_rows.map{|s| s.regular}.sum
    plus_sales = dispenser_rows.map{|s| s.plus}.sum
    premium_sales = dispenser_rows.map{|s| s.premium}.sum
    diesel_sales = dispenser_rows.map{|s| s.diesel}.sum
    total_sales = regular_sales + plus_sales + premium_sales + diesel_sales
    return total_sales, regular_sales, plus_sales, premium_sales, diesel_sales
  end

  def last_rate_per_gallon
    last_regular_delivery = FuelDelivery.where("regular_gallons > 0 and delivery_date < ?",self.date).order("id desc").first
    last_premium_delivery = FuelDelivery.where("premium_gallons > 0 and delivery_date < ?",self.date).order("id desc").first
    last_diesel_delivery = FuelDelivery.where("diesel_gallons > 0 and delivery_date < ?",self.date).order("id desc").first
    return last_regular_delivery.regular_per_gallon.to_f,
      last_premium_delivery.premium_per_gallon.to_f, last_diesel_delivery.diesel_per_gallon.to_f
  end

  def fuel_sales
    Transaction.where(:category => 'fuel_sale', :date => self.date_range)
  end

  def dispenser_sales_by_grade
    sales = self.dispenser_sales
    results = {'regular' => {}, 'plus' => {}, 'premium' => {}, 'diesel' => {}}
    results['regular']['amount'] = sales.map{|e| e.regular}.sum
    results['regular']['gallons'] = sales.map{|e| e.regular_volume}.sum
    results['plus']['amount'] = sales.map{|e| e.plus}.sum
    results['plus']['gallons'] = sales.map{|e| e.plus_volume}.sum
    results['premium']['amount'] = sales.map{|e| e.premium}.sum
    results['premium']['gallons'] = sales.map{|e| e.premium_volume}.sum
    results['diesel']['amount'] = sales.map{|e| e.diesel}.sum
    results['diesel']['gallons'] = sales.map{|e| e.diesel_volume}.sum
    return results
  end

  def dispenser_volumes
    gasoline_volume = dispenser_sales.map(&:regular_volume).sum +
      dispenser_sales.map(&:plus_volume).sum +
      dispenser_sales.map(&:premium_volume).sum
    diesel_volume = dispenser_sales.map(&:diesel_volume).sum
    return gasoline_volume, diesel_volume
  end

  def delivery_gallons
    gasoline_gallon = fuel_deliveries.map(&:regular_gallons).sum +
      fuel_deliveries.map(&:premium_gallons).sum
    diesel_gallon = fuel_deliveries.map(&:diesel_gallons).sum
    return gasoline_gallon, diesel_gallon
  end

  def gallons_sold
    current_week = self
    previous_week = self.previous_week
    current_dispenser_volumes = current_week.dispenser_volumes
    previous_dispenser_volumes = previous_week.dispenser_volumes
    gasoline_gallons = (current_dispenser_volumes[0] - previous_dispenser_volumes[0]).to_f
    diesel_gallons = (current_dispenser_volumes[1] - previous_dispenser_volumes[1]).to_f
    return gasoline_gallons, diesel_gallons
  end

  def dispenser_volumes_by_basic_fuel_type
    plus_volume = dispenser_sales.map(&:plus_volume).sum
    premium_volume = dispenser_sales.map(&:premium_volume).sum + (0.5 * plus_volume)
    regular_volume = dispenser_sales.map(&:regular_volume).sum + (0.5 * plus_volume)
    diesel_volume = dispenser_sales.map(&:diesel_volume).sum
    total_volume = premium_volume + regular_volume + diesel_volume
    return {:total => total_volume.to_f, :premium => premium_volume.to_f,
      :regular => regular_volume.to_f, :diesel => diesel_volume.to_f}
  end

  def dispenser_sales_by_basic_fuel_type
    plus = dispenser_sales.map(&:plus).sum
    premium = dispenser_sales.map(&:premium).sum + (0.5 * plus)
    regular = dispenser_sales.map(&:regular).sum + (0.5 * plus)
    diesel = dispenser_sales.map(&:diesel).sum
    total = premium + regular + diesel
    return {:total => total, :premium => premium, :regular => regular, :diesel => diesel}
  end

  def net_volume
    current_week = self
    previous_week = self.previous_week
    current_volume = current_week.dispenser_volumes_by_basic_fuel_type
    previous_volume = previous_week.dispenser_volumes_by_basic_fuel_type
    volume = {}
    grades = current_volume.keys
    grades.each {|grade| volume[grade] = current_volume[grade] - previous_volume[grade]}
    return volume
  end

  def net_sales
    current_week = self
    previous_week = self.previous_week
    current_sales = current_week.dispenser_sales_by_basic_fuel_type
    previous_sales = previous_week.dispenser_sales_by_basic_fuel_type
    sales = {}
    grades = current_sales.keys
    grades.each {|grade| sales[grade] = current_sales[grade] - previous_sales[grade]}
    return sales
  end

  def dispenser_net(blended = false)
    return DispenserSalesTotal.net_sales_for_period(self.previous_week, self, blended)
  end

  def estimated_gross_profit
    grades = gather_delivery_stats
    net_volume = self.net_volume
    net_sales = self.net_sales
    total_gallons = 0.0
    results = {'total_margin' => 0.0, 'overall_per_gallon' => 0.0}
    grades.each do |grade|
      key = grade['keys'].first
      per_gallon = grade['per_gallon']
      retail = net_sales[key].to_f
      gallons = net_volume[key]
      total_gallons += gallons
      per_gallon_commission = per_gallon + 0.07
      cost = gallons * per_gallon_commission
      margin_sales = retail - cost
      margin_per_gallon = (retail - cost) / gallons
      results[key.to_s] = {'gallons' => gallons, 'per_gallon' => per_gallon,
        'per_gallon_commission' => per_gallon_commission,
        'retail' => retail, 'cost' => cost, 'margin_sales' => margin_sales,
        'margin_per_gallon' => margin_per_gallon}
      results['total_margin'] += margin_sales
    end
    results['overall_per_gallon'] = results['total_margin'] / total_gallons
    return results, grades
  end

  #private

  def gather_delivery_stats
    net_volume = self.net_volume
    id = self.fuel_deliveries.last
    deliveries = FuelDelivery.where("id <= ?",id).order("id desc").limit(40).to_a
    grades = []
    (net_volume.keys - [:total]).each do |key|
      per_gallon_key = key == :premium ? "premium_per_gallon" : key.to_s + "_per_gallon"
      gallons_key = key == :premium ? "premium_gallons" : key.to_s + "_gallons"
      grades << {'keys' => [key, gallons_key, per_gallon_key], 'per_gallon' => 0.0, 'entries' => []}
    end

    grades.each do |grade|
      volume_key = grade['keys'].first
      gallons_key = grade['keys'][1]
      per_gallon_key = grade['keys'].last
      gallons_sold = net_volume[volume_key]
      total_gallons_delivered = 0.0
      matching_deliveries = []
      #puts "#{volume_key}  --  #{gallons_key}  --  #{gallons_sold}"
      deliveries.select{|d| d[gallons_key] > 0.0}.each do |delivery|
        total_gallons_delivered += delivery[gallons_key].to_f
        matching_deliveries << delivery
        #puts "\t#{delivery[gallons_key]}  --  #{total_gallons_delivered}"
        break if total_gallons_delivered >= gallons_sold
      end
      #puts "\n"
      total_gallons_delivered = 0.0
      matching_deliveries.each do |delivery|
        delivered_gallons = delivery[gallons_key].to_f
        total_gallons_delivered += delivered_gallons
        if total_gallons_delivered >= gallons_sold
          delivered_gallons = delivered_gallons - (total_gallons_delivered - gallons_sold)
          grade['entries'] << {'gallons' => delivered_gallons, 'per_gallon' => delivery[per_gallon_key].to_f}
        else
          grade['entries'] << {'gallons' => delivered_gallons, 'per_gallon' => delivery[per_gallon_key].to_f}
        end
        #puts "\t#{total_gallons_delivered}  --  #{delivery[gallons_key]}  --  #{delivered_gallons}  --  #{delivery[per_gallon_key]}"
      end
      grade['per_gallon'] = (grade['entries'].map{|d| d['gallons'] * d['per_gallon']}.sum / gallons_sold).to_f
    end

    return grades
  end

  def self.fuel_reconcile(weeks)
    results = []
    weeks.each do |current_week|
      previous_week = current_week.previous_week
      net_sales = DispenserSalesTotal.net_sales_for_period(previous_week, current_week, false)
      volume_previous_week = previous_week.tank_volume
      volume_current_week = current_week.tank_volume
      deliveries = current_week.fuel_deliveries
      ['regular', 'premium', 'diesel'].each do |grade|
        fuel_grade = grade == 'premium' ? 'premium_gallons' : grade + "_gallons"
        results << {'grade' => grade,
          'tank_volume_previous_week' => volume_previous_week.public_send(grade),
          'tank_volume_current_week' => volume_current_week.public_send(grade),
          'dispenser_sales' => net_sales.public_send(grade).gallons,
          'delivered_gallons' => deliveries.map{|d| d.public_send(fuel_grade)}.sum}
      end
    end
    return results
  end

  def self.fuel_reconcile_period(weeks)
    results = []
    beginning_tank_volume = weeks.first.previous_week.tank_volume
    ending_tank_volume = weeks.last.tank_volume
    deliveries = weeks.flat_map{|w| w.fuel_deliveries}
    net_sales = DispenserSalesTotal.net_sales_for_period(weeks.first.previous_week, weeks.last, false)
    regular_gallons = deliveries.map(&:regular_gallons).sum
    premium_gallons = deliveries.map(&:premium_gallons).sum
    diesel_gallons = deliveries.map(&:diesel_gallons).sum
    regular_hash = {'beginning_volume' => beginning_tank_volume.regular,
      'gallons_delivered' => regular_gallons, 'gallons_sold' => net_sales.regular.gallons.to_i,
      'ending_tank_volume' => ending_tank_volume.regular,
      'calculated_volume' => beginning_tank_volume.regular - net_sales.regular.gallons.to_i + regular_gallons}
    premium_hash = {'beginning_volume' => beginning_tank_volume.premium,
      'gallons_delivered' => premium_gallons, 'gallons_sold' => net_sales.premium.gallons.to_i,
      'ending_tank_volume' => ending_tank_volume.premium,
      'calculated_volume' => beginning_tank_volume.premium - net_sales.premium.gallons.to_i + premium_gallons}
    diesel_hash = {'beginning_volume' => beginning_tank_volume.diesel,
      'gallons_delivered' => diesel_gallons, 'gallons_sold' => net_sales.diesel.gallons.to_i,
      'ending_tank_volume' => ending_tank_volume.diesel,
      'calculated_volume' => beginning_tank_volume.diesel - net_sales.diesel.gallons.to_i + diesel_gallons}
    return {'regular' => regular_hash, 'premium' => premium_hash, 'diesel' => diesel_hash}
  end

  # => Migration
=end

  class PostingObject < HashManager
    def is_fuel_delivery?
      self.type == 'fd'
    end
    def is_tank_volume?
      self.type == 'tv'
    end
    def is_dispenser_sales?
      self.type == 'ds'
    end
  end
end
