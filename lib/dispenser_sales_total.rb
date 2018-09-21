class DispenserSalesTotal < HashManager

    GRADES = ['regular', 'plus', 'premium', 'diesel']

    attr_accessor   :week
    attr_accessor   :blended

    def initialize(week, blended)
        @week = week
        @blended = blended
        super(total_by_grade(week, blended))
    end

    def self.net_sales_for_period(first_week, last_week, blended = false)
      net_sales = DispenserSalesNet.new(DispenserSalesTotal.initial_hash(blended))
      sales_total_first_week = DispenserSalesTotal.new(first_week, blended)
      sales_total_last_week = DispenserSalesTotal.new(last_week, blended)
      DispenserSalesTotal.function_names(blended).each do |function_name|
        value = self.difference(sales_total_first_week, sales_total_last_week, function_name)
        net_sales.set_value(function_name, value)
      end
      return net_sales
    end

    def self.difference(sales_total_first_week, sales_total_last_week, function_name)
      translation = {"regular.amount" =>"regular_cents", "regular.gallons" => "regular_gallons",
         "plus.amount" => "plus_cents", "plus.gallons" => "plus_gallons",
         "premium.amount" => "premium_cents", "premium.gallons" => "premium_gallons",
         "diesel.amount" => "diesel_cents", "diesel.gallons" => "diesel_gallons"}

      grade_type = translation[function_name]
      first_week_offset = last_week_offset = 0.0
      first_week = sales_total_first_week.week
      last_week = sales_total_last_week.week
      [1,2,3,4,5,6].each do |number|
        first_week_offset += DispenserOffset.dispenser(number).grade_type(grade_type).
          where("start_date <= ?", first_week.date).order(:start_date).last.offset.to_f
        last_week_offset += DispenserOffset.dispenser(number).grade_type(grade_type).
          where("start_date <= ?", last_week.date).order(:start_date).last.offset.to_f
      end
      last_week_value = sales_total_last_week.get_value(function_name)
      first_week_value = sales_total_first_week.get_value(function_name)
      return (last_week_value + last_week_offset) - (first_week_value + first_week_offset)
    end
=begin
    def self.net_sales_for_period(first_week, last_week, blended = false)
      net_sales = DispenserSalesNet.new(DispenserSalesTotal.initial_hash(false))
      sales_total_first_week = DispenserSalesTotal.new(first_week, true)
      sales_total_last_week = DispenserSalesTotal.new(last_week, true)
      DispenserSalesTotal.function_names(false).each do |function_name|
        value = sales_total_last_week.get_value(function_name) -
          sales_total_first_week.get_value(function_name)
        if ['regular','premium'].include?(function_name.split('.').first)
          plus_function_name = 'plus.' + function_name.split('.').last
          value += (sales_total_last_week.get_value(plus_function_name) -
            sales_total_first_week.get_value(plus_function_name)) / 2.0
        end
        net_sales.set_value(function_name, value)
      end
      return net_sales

      net_sales = DispenserSalesNet.new(DispenserSalesTotal.initial_hash(blended))
      sales_total_first_week = DispenserSalesTotal.new(first_week, blended)
      sales_total_last_week = DispenserSalesTotal.new(last_week, blended)
      DispenserSalesTotal.function_names(blended).each do |function_name|
          value = sales_total_last_week.get_value(function_name) -
              sales_total_first_week.get_value(function_name)
          net_sales.set_value(function_name, value)
      end
      return net_sales
    end
=end
    class DispenserSalesNet < HashManager
        def initialize(initial_hash)
            super(initial_hash)
        end
    end

    private

    def self.initial_hash(blended = true)
        hash = {}
        if blended
          GRADES.each {|grade| hash[grade] = {'amount' => nil, 'gallons' => nil}}
        else
          (GRADES - ['plus']).each {|grade| hash[grade] = {'amount' => nil, 'gallons' => nil}}
        end
        return hash
    end

    def self.function_names(blended)
        names = []
        grades = blended ? GRADES : GRADES - ['plus']
        grades.each do |grade|
            ['amount','gallons'].each {|column| names << grade + '.' + column}
        end
        return names
    end

    def total_by_grade(week, blended)
        sales = week.dispenser_sales
        hash = DispenserSalesTotal.initial_hash(@blended)
        if blended
          hash['regular']['amount'] = sales.map{|e| e.regular}.sum
          hash['regular']['gallons'] = sales.map{|e| e.regular_volume}.sum.to_f
          hash['plus']['amount'] = sales.map{|e| e.plus}.sum
          hash['plus']['gallons'] = sales.map{|e| e.plus_volume}.sum.to_f
          hash['premium']['amount'] = sales.map{|e| e.premium}.sum
          hash['premium']['gallons'] = sales.map{|e| e.premium_volume}.sum.to_f
        else
          hash['regular']['amount'] = sales.map{|e| e.regular}.sum +
            sales.map{|e| e.plus}.sum * 0.65
          hash['regular']['gallons'] = sales.map{|e| e.regular_volume}.sum.to_f +
            sales.map{|e| e.plus_volume}.sum.to_f * 0.65
          hash['premium']['amount'] = sales.map{|e| e.premium}.sum +
            sales.map{|e| e.plus}.sum * 0.35
          hash['premium']['gallons'] = sales.map{|e| e.premium_volume}.sum.to_f +
            sales.map{|e| e.plus_volume}.sum.to_f * 0.35
        end
        hash['diesel']['amount'] = sales.map{|e| e.diesel}.sum
        hash['diesel']['gallons'] = sales.map{|e| e.diesel_volume}.sum.to_f
        return hash
    end
end
