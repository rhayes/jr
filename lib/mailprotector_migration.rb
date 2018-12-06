class MailprotectorMigration

  attr_accessor   :matching_tables
  attr_accessor   :production_nonmatching_tables
  attr_accessor   :development_nonmatching_tables
  attr_accessor   :development_columns
  attr_accessor   :production_columns
  attr_accessor   :matching_columns
  attr_accessor   :production_nonmatching_columns
  attr_accessor   :development_nonmatching_columns

  def self.populate_all
    DevelopmentTable.populate
    ProductionTable.populate
    DevelopmentColumn.populate
    ProductionColumn.populate
    DevelopmentMissingModel.populate
    ProductionMissingModel.populate
  end

  def self.build
    instance = MailprotectorMigration.new
    instance.doit
    return instance
  end

  def self.dump_table_sql
    instance = MailprotectorMigration.new
    instance.doit
    instance.dump_tables
    return instance
  end

  def self.reports
    instance = self.build
    instance.table_report
    instance.nonmatching_column_report
    instance.nonmatching_column_report('production')
    return instance
  end

  def dump_tables
    self.development_nonmatching_tables.each do |table|
      sql_file = File.expand_path("~/Downloads/sqlbackup/#{table}.sql")
      command = "mysqldump -uvctiadmin -pv1rtpr0tect -h mpx-dev.ci8dabgyz2xs.us-east-1.rds.amazonaws.com mailprotector_production #{table} > #{sql_file}"
      exit_code = system(command)
      puts "Exit code:  #{exit_code}"
    end
  end

  def column_json_array(columns)
    return columns.as_json.map{|hash| hash.except('id')}
    keys = columns.first.as_json.keys - ['id']
    return columns.inject([]) {|array,column| array <<
      keys.inject({}) {|hash,key| hash.update(key => column[key]);hash};array}
  end

  def doit
    self.matching_tables = ProductionTable.pluck(:table) & DevelopmentTable.pluck(:table)
    self.matching_tables -= DevelopmentMissingModel.all.map(&:table)
    self.matching_tables -= ProductionMissingModel.all.map(&:table)
    self.development_nonmatching_tables = DevelopmentTable.pluck(:table) - ProductionTable.pluck(:table)
    self.production_nonmatching_tables = ProductionTable.pluck(:table) - DevelopmentTable.pluck(:table)
    self.development_columns = DevelopmentColumn.where(:table => self.matching_tables)
    self.production_columns = ProductionColumn.where(:table => self.matching_tables)
    production_hash_array = production_columns.as_json.map{|hash| hash.except('id')}
    development_hash_array = development_columns.as_json.map{|hash| hash.except('id')}
    self.matching_columns = production_hash_array & development_hash_array
    self.development_nonmatching_columns = development_hash_array - production_hash_array
    self.production_nonmatching_columns = production_hash_array - development_hash_array
  end

  def table_report
    book = Spreadsheet::Workbook.new
    sheet = book.create_worksheet
    sheet.column(0).width = 45
    sheet.column(1).width = 45
    sheet.column(2).width = 45

    title_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 16
    header_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14
    left_justified_format = Spreadsheet::Format.new :horizontal_align => :left, :size => 14
    right_justified_format = Spreadsheet::Format.new :horizontal_align => :right, :size => 14, :number_format => '#,###,##0.00'
    centre_justified_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14

    sheet.merge_cells(0, 0, 0, 2)
    sheet.row(0).default_format = title_format
    sheet.row(0).push "Development/Production Table Matches"
    sheet.row(1).default_format = header_format
    sheet.row(1).push "Both", "Development Only", "Production Only"

    self.matching_tables.each_with_index do |matching_table,index|
      row = index + 2
      sheet.row(row).default_format = left_justified_format
      sheet.row(row).push matching_table, self.development_nonmatching_tables[row],
        self.production_nonmatching_tables[row]
    end

    file_path = File.expand_path("~/Documents/matching_tables_#{Date.today.to_s.gsub("-","_")}.xls")
    book.write file_path

    return
  end

  def nonmatching_column_report(database = 'development')
    book = Spreadsheet::Workbook.new
    sheet = book.create_worksheet
    sheet.column(0).width = 45
    sheet.column(1).width = 45
    sheet.column(2).width = 45

    title_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 16
    header_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14
    left_justified_format = Spreadsheet::Format.new :horizontal_align => :left, :size => 14
    right_justified_format = Spreadsheet::Format.new :horizontal_align => :right, :size => 14, :number_format => '#,###,##0.00'
    centre_justified_format = Spreadsheet::Format.new :horizontal_align => :centre, :size => 14

    sheet.merge_cells(0, 0, 0, 2)
    sheet.row(0).default_format = title_format
    sheet.row(0).push "Columns in #{database} only for matching tables"
    sheet.row(1).default_format = header_format
    sheet.row(1).push "Table", "Column", "Sql Type"

    table_columns = database == 'development' ? self.development_nonmatching_columns :
      self.production_nonmatching_columns

    table_columns.each_with_index do |table_column,index|
      row = index + 2
      sheet.row(row).default_format = left_justified_format
      sheet.row(row).push table_column['table'], table_column['name'], table_column['sql_type']
    end

    file_path = File.expand_path("~/Documents/#{database}_nonmatching_colums_#{Date.today.to_s.gsub("-","_")}.xls")
    book.write file_path

    return
  end

end
