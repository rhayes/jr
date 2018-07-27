class Fd < ActiveRecord::Base
  self.table_name = "fd"

  def self.get_fuel_deliveries
    columns = FuelDelivery.first.as_json.keys.sort - ['id']
    ActiveRecord::Base.transaction do
      self.delete_all
      deliveries = FuelDelivery.all.order("delivery_date, id")
      deliveries.each do |delivery|
        fd = Fd.new
        columns.each {|c| fd[c] = delivery[c]}
        fd.save!
      end
    end
  end
end
