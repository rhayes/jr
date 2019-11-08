class FuelDelivery < ActiveRecord::Base

  belongs_to    :week
  #belongs_to    :fuel_transaction, :class_name => 'Transaction',
  #  :foreign_key => 'transaction_id', :optional => true
  has_many      :transactions

  monetize 	:monthly_tank_charge_cents, with_model_currency: :monthly_tank_charge_currency

  GRADES = ['regular','premium','diesel']

  def self.to_hash_array
    array = []
    self.all.each do |delivery|
      hash = {:parent => {:id => delivery.id, :week_id => delivery.week_id,
        :date => delivery.delivery_date.to_s, :invoice_number => delivery.invoice_number,
        :monthly_tank_charge => delivery.monthly_tank_charge.to_f,
        :adjustment => delivery.adjustment_cents.to_f / 100.0,
        :storage_tank_fee => delivery.storage_tank_fee}, :children => []}
      ['regular', 'premium', 'diesel'].each do |grade_name|
        next unless delivery[grade_name + "_gallons"] > 0
        hash[:children] << {:grade_name => grade_name, :grade_id => nil,
          :fuel_delivery_id => delivery.id,  :gallons => delivery[grade_name + "_gallons"],
          :per_gallon => delivery[grade_name + "_per_gallon"]}
      end
      array << hash
    end
    array
    #self.all.as_json
  end

  def self.to_json_file
    json = JSON.pretty_generate(to_hash_array)
    file = File.open(File.expand_path("~/Documents/fuel_deliveries.json"), 'w') {|file| file.write(json.force_encoding("UTF-8"))}
  end

  def self.totals_json_file
    array = self.all.order(:id).inject([]) {|array,fd|
      array << {:id => fd.id, :total => fd.total.to_f}; array}
    json = JSON.pretty_generate(array)
    file = File.open(File.expand_path("~/Documents/fuel_delivery_total.json"), 'w') {|file| file.write(json.force_encoding("UTF-8"))}
  end

  def regular_total
    total = (self.regular_gallons * self.regular_per_gallon +
      self.regular_gallons * self.storage_tank_fee).round(2)
    return Money.new((100.0 * total).to_i)
  end

  def regular_total_without_tank_fee
    total = (self.regular_gallons * self.regular_per_gallon).round(2)
    return Money.new((100.0 * total).to_i)
  end

  def premium_total
    total = (self.premium_gallons * self.premium_per_gallon +
      self.premium_gallons * self.storage_tank_fee).round(2)
    return Money.new((100.0 * total).to_i)
  end

  def premium_total_without_tank_fee
    total = (self.premium_gallons * self.premium_per_gallon).round(2)
    return Money.new((100.0 * total).to_i)
  end

  def diesel_total
    total = (self.diesel_gallons * self.diesel_per_gallon +
      self.diesel_gallons * self.storage_tank_fee).round(2)
    return Money.new((100.0 * total).to_i)
  end

  def diesel_total_without_tank_fee
    total = (self.diesel_gallons * self.diesel_per_gallon).round(2)
    return Money.new((100.0 * total).to_i)
  end

  def total
    return self.regular_total + self.premium_total +
      self.diesel_total + self.monthly_tank_charge + Money.new(self.adjustment_cents)
  end

  def gallons(grade)
    return self[grade + "_gallons"].to_f
  end

  def per_gallon(grade)
    return self[grade + "_per_gallon"].to_f
  end

  def self.summary(weeks)
    deliveries = self.where(:week_id => weeks.map(&:id))
    regular = deliveries.map(&:regular_gallons).sum
    premium = deliveries.map(&:premium_gallons).sum
    diesel = deliveries.map(&:diesel_gallons).sum
    return HashManager.new({:regular => regular, :premium => premium, :diesel => diesel,
      :total => regular + premium + diesel})
  end

  def self.from_date_by_grade_descending(end_date, grade)
    fuel_deliveries = FuelDelivery.where("delivery_date <= ?", end_date).
      where("#{grade + "_gallons"} > 0").order("delivery_date desc")
  end

  def self.confirm_week(tax_year = Date.today.year)
    array = []
    deliveries = FuelDelivery.joins(:week).select("fuel_deliveries.id, fuel_deliveries.delivery_date, weeks.id as week_id")
    deliveries.each do |delivery|
      week = delivery.week
      array << FuelDelivery.find(delivery.id) unless week.date_range.include?(delivery.delivery_date)
    end
    return array
  end

  def self.match_with_transactions(year = Date.today.year)
    deliveries = FuelDelivery.where(:delivery_date => Date.new(year, 1, 1)..Date.new(year, 12, 31))
    array = []
    deliveries.each do |delivery|
      match = delivery.match_transaction
      array << delivery unless match
    end
    return array
  end

  def match_two_transactions(first_transaction)
    unless first_transaction.fuel_delivery_id.nil? || first_transaction.fuel_delivery_id == self.id
      raise "first transaction alredy associated with a fuel delivery"
    end
    dates = self.delivery_date..self.delivery_date+10.days
    balance_cents = self.total.cents - first_transaction.amount.cents
    second_transaction = Transaction.fuel_cost.
      where(:amount_cents => balance_cents, :date => dates).first
    return false if second_transaction.nil?
    ActiveRecord::Base.transaction do
      [first_transaction, second_transaction].each do |transaction|
        self.update_column(:transaction_id, transaction.id)
        transaction.update_attributes(:week_id => self.week_id, :fuel_delivery_id => self.id)
      end
    end
    return true
  end

  def match_transaction(dates = nil)
    dates = self.delivery_date..self.delivery_date+10.days if dates.nil?
    transaction = Transaction.fuel_cost.
      where(:amount_cents => self.total.cents, :date => dates).first
    return false if transaction.nil?
    ActiveRecord::Base.transaction do
      self.update_column(:transaction_id, transaction.id)
      transaction.update_attributes(:week_id => self.week_id, :fuel_delivery_id => self.id)
    end
    return true
  end

  def self.insert_delivery(beginning_id, invoice_number, date)
    deliveries = FuelDelivery.where("id >= ?", beginning_id).order("id")
    ActiveRecord::Base.transaction do
      FuelDelivery.create({:invoice_number => invoice_number, :delivery_date => date})
      array = deliveries.map{|d| d.as_json}
      deliveries.delete_all
      array.each do |delivery|
        delivery.delete('id')
        FuelDelivery.create(delivery)
      end
    end
  end

  def xx(grade, total_gallons, offset)
    deliveries = []
    results.keys.each do |grade|
      fuel_deliveries = FuelDelivery.from_date_by_grade_descending(self.date, grade)
      accumulated_gallons = 0.0
      fuel_deliveries.each do |fuel_delivery|
        per_gallon = fuel_delivery.per_gallon(grade)
        gallons = fuel_delivery.gallons(grade)
        if accumulated_gallons + gallons >= total_gallons
          applied_gallons = total_gallons - accumulated_gallons
        else
          applied_gallons = gallons
        end
        accumulated_gallons += applied_gallons
        grade_object.per_gallon += (per_gallon * (applied_gallons / total_gallons)).to_f
        grade_object.amount = (grade_object.per_gallon * grade_object.gallons).to_f
        break if accumulated_gallons >= total_gallons
      end
    end
  end

  def get_descending_deliveries(grade, gallons, offset = 0.0)
    deliveries = FuelDelivery.from_date_by_grade_descending(self.delivery_date, grade).limit(20)
    columns = ['id', 'date', 'invoice_number', 'gallons', 'per_gallon', 'applied_gallons', 'skip_gallons']
    fuel_deliveries = []
    deliveries.each do |delivery|
      hash = {}
      hash['id'] = delivery['id']
      hash['delivery_date'] = delivery['delivery_date']
      hash['invoice_number'] = delivery['invoice_number']
      hash['gallons'] = delivery.gallons(grade).to_f
      hash['per_gallon'] = delivery.per_gallon(grade).round(4)
      hash['applied_gallons'] = 0.0
      hash['skip_gallons'] = 0.0
      fuel_deliveries << HashManager.new(hash)
    end
    offset_gallons = offset.round(2)
    total_gallons = 0.0
    applied_gallons = 0.0
    fuel_deliveries.each_with_index do |delivery,index|
      if offset_gallons > delivery.gallons
        delivery.skip_gallons = delivery.gallons.round(2)
        offset_gallons -= delivery.gallons
      else
        delivery.skip_gallons = offset_gallons
        available_gallons = delivery.gallons - delivery.skip_gallons
        offset_gallons = 0.0
        if total_gallons + available_gallons >= gallons
          applied_gallons = gallons - total_gallons
          total_gallons += applied_gallons
        else
          total_gallons += available_gallons
          applied_gallons = available_gallons.round(2)
        end
      end
      delivery.applied_gallons = applied_gallons.round(2)

      return fuel_deliveries.slice(0..index) if total_gallons >= gallons
    end
    raise "FuelDelivery.get_descending_deliveries reached end"
  end
  class FuelSummary < HashManager
    def grade_array
      grades = FuelDelivery::GRADES + ['total']
      grades.inject([]) {|array,grade| array << self.send(grade); array}
    end
  end
end
=begin
    def get_descending_deliveries(grade, offset)
      deliveries = FuelDelivery.from_date_by_grade_descending(self.delivery_date, grade).limit(10)
      columns = ['id', 'date', 'invoice_number', 'gallons', 'per_gallon', 'applied_gallons', 'skip_gallons']
      fuel_deliveries = []
      deliveries.each do |delivery|
        hash = {}
        hash['id'] = delivery['id']
        hash['delivery_date'] = delivery['delivery_date']
        hash['invoice_number'] = delivery['invoice_number']
        hash['gallons'] = delivery.gallons(grade)
        hash['per_gallon'] = delivery.per_gallon(grade)
        hash['applied_gallons'] = 0
        hash['skip_gallons'] = 0
        fuel_deliveries << HashManager.new(hash)
      end
      offset_gallons = offset
      fuel_deliveries.each_with_index do |delivery,index|
        if offset_gallons < delivery.gallons
          delivery.skip_gallons = offset_gallons
          return fuel_deliveries.slice(index..10)
        elsif offset_gallons == delivery.gallons
          return fuel_deliveries.slice(index+1..10)
        end
        offset_gallons -= delivery.gallons
      end
      raise "FuelDelivery.get_descending_deliveries reached end"
    end
  end
=end
#end
