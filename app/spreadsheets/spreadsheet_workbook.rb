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

  def auto_fit(sheet)
      (0...sheet.column_count).each do |col_idx|
      column = sheet.column(col_idx)
      column.width = column.each_with_index.map do |cell, row|
          chars = cell.present? ? cell.to_s.strip.split('').count + 4 : 1
          ratio = sheet.row(row).format(col_idx).font.size / 10
          (chars * ratio).round
      end.max
      end
  end

  def base_folder
    File.expand_path("~/Documents/jr_reports/")
  end

  def fuel_profit_folder(tax_year)
    base_folder + "/#{tax_year}" + "/fuel_profit_reports"
  end

  def format_date_as_string(date)
    "#{date.year}_#{date.month.to_s.rjust(2,'0')}_#{date.day.to_s.rjust(2,'0')}"
  end

  def build_file_path(parts)
    parts.join("/")
  end

  def set_cell_formats(row, formats)
    formats.each_with_index {|format,index| row.set_format(index,format)}
  end

  def formath(align, size, other = {})
    Spreadsheet::Format.new({:horizontal_align => align, :size => size}.merge(other))
  end

  def formath_left(size, other = {})
    Spreadsheet::Format.new({:horizontal_align => :left, :size => size}.merge(other))
  end

  def formath_center(size, other = {})
    Spreadsheet::Format.new({:horizontal_align => :centre, :size => size}.merge(other))
  end

  def formath_right(size, other = {})
    Spreadsheet::Format.new({:horizontal_align => :right, :size => size}.merge(other))
  end
end
