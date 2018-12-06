class DevelopmentTable < ActiveRecord::Base
  def self.populate
    self.delete_all
    tables = File.read(File.expand_path("~/Documents/development_tables.csv")).split("\n")
    tables.each {|table| self.create({:table => table})}
  end
end
