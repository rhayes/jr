class DispenserOffset < ActiveRecord::Base

  scope		:dispenser, lambda{|number| where(:number => number)}
  scope		:grade_type, lambda{|grade_type| where(:grade_type => grade_type)}

  GRADE_TYPES = ['regular_cents', 'regular_gallons', 'plus_cents', 'plus_gallons',
    'premium_cents', 'premium_gallons', 'diesel_cents', 'diesel_gallons']

  def self.init
    return if self.count != 0
    start_date = Date.new(2016,8,1)
    [1,2,3,4,5,6].each do |number|
      GRADE_TYPES.each do |grade_type|
        DispenserOffset.create(:number => number, :start_date => start_date, :grade_type => grade_type)
      end
    end
  end

  #def self.get_offset(number, grade_type, start_date)
  #  return self.dispenser(number).grade_type(grade_type).
  #    where("start_date <= ?", start_date).order(:start_date).last.offset
  #end

  def self.get_offset(number, grade_type, start_date)
    offset = self.dispenser(number).grade_type(grade_type).
      where("start_date <= ?", start_date).order(:start_date).last.offset
    return grade_type.include?("_cents") ? Money.new(100 * offset) : offset.to_f
  end

end
