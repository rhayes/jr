class DispenserSalesTotal < HashManager

    GRADES = ['regular', 'plus', 'premium', 'diesel']

    attr_accessor   :week
    attr_accessor   :blended

    def initialize(week, blended)
        @week = week
        @blended = blended
        super(total_by_grade(week, blended))
    end

    def self.net_sales_for_period(first_week, last_week, blended)
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
            sales.map{|e| e.plus}.sum / 2.0
          hash['regular']['gallons'] = sales.map{|e| e.regular_volume}.sum.to_f +
            sales.map{|e| e.plus_volume}.sum.to_f / 2.0
          hash['premium']['amount'] = sales.map{|e| e.premium}.sum +
            sales.map{|e| e.plus}.sum / 2.0
          hash['premium']['gallons'] = sales.map{|e| e.premium_volume}.sum.to_f +
            sales.map{|e| e.plus_volume}.sum.to_f / 2.0
        end
        hash['diesel']['amount'] = sales.map{|e| e.diesel}.sum
        hash['diesel']['gallons'] = sales.map{|e| e.diesel_volume}.sum.to_f
        return hash
    end
end
