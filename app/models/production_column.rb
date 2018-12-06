class ProductionColumn < ActiveRecord::Base
  def self.populate
    self.delete_all
    rows = File.read(File.expand_path("~/Documents/production_columns.csv")).split("\n")
    rows.each do |row|
      table, name, sql_type = CSV.parse(row).first
      sql_type = 'enum' if sql_type.starts_with?('enum')
      puts "Table:  #{table}  --  Name:  #{name}  --  sql_type:  #{sql_type}(#{sql_type.size})"
      self.create({:table => table, :name => name, :sql_type => sql_type})
    end
  end
end
