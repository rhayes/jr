class FuelProfitSpreadsheet < Spreadsheet::Workbook
  def self.weekly_report(week)
    report = FuelProfitSpreadsheet.new
    report.create_weekly_report(week)
  end

  def create_weekly_report(week)
  end
end
