class MigrateLib
  def self.do_all
    Week.to_json_file
    TankVolume.to_json_file
    FuelDelivery.to_json_file
    Transaction.to_json_file
    DispenserSale.to_json_file
  end
end
