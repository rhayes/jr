class SpreadsheetWorkbook < Spreadsheet::Workbook

  attr_accessor   :sheet
  attr_accessor   :width
  attr_accessor   :column_size

  def initialze(width, column_size = 1)
		@sheet = self.create_worksheet
    @width = width
    @column_size = column_size
    [0..width-1].each {|column| @sheet.column(column).width = width}
  end
  
end
