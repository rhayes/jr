class FuelBalance < HashManager

  def initialize
    super({:entries => []})
  end

  def self.create(weeks, dispenser_net = nil)
    dispenser_net = DispenserPeriodNet.create(weeks.first, weeks.last) if dispenser_net.nil?
    instance = self.new
    instance.build(weeks, dispenser_net)
    instance
  end

  def build(weeks, dispenser_net)
    beginning_volume = weeks.first.previous_week.tank_volume
    ending_volume = weeks.last.tank_volume
    gallons_sold = dispenser_net.gallons
    gallons_delivered = FuelDelivery.summary(weeks)
    calculated = FuelBalanceEntry.new({:regular => nil, :premium => nil, :diesel => nil, :total => nil})
    calculated._columns.each {|grade| calculated[grade] = beginning_volume.send(grade) +
      gallons_delivered.send(grade) - gallons_sold.send(grade)}
    difference = FuelBalanceEntry.new({:regular => nil, :premium => nil, :diesel => nil, :total => nil})
    difference._columns.each {|grade| difference[grade] = ending_volume.send(grade) - calculated.send(grade)}

    row_defs = [["Beginning Volume", beginning_volume], ["Sales", gallons_sold], ["Delivered", gallons_delivered],
      ["Calculated", calculated], ["Ending Volume", ending_volume], ["Difference", difference]]
    row_defs.each.with_index do |row_def, index|
      entries << [row_def.first] +
    end
    row_defs.each_with_index do |row_def, index|
      sheet_row = sheet.row(row_no + index + 2)
      set_cell_formats(sheet_row, [formath_left(10)] + Array.new(4, formath_right(10, number_format)))
      push_row(sheet_row, columns.inject([row_def.first]) {|array,c| array << row_def.last.send(c); array})
    end

    class FuelBalanceEntry < HashManager
      def grade_array
        grades = FuelDelivery::GRADES + ['total']
        grades.inject([]) {|array,grade| array << self.send(grade); array}
      end
    end
end
