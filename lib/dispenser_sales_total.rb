class DispenserSalesTotal < HashManager
    
    GRADES = ['regular', 'plus', 'premium', 'diesel']

    attr_accessor   :week

    def initialize(week)
        @week = week
        super(total_by_grade(week))
    end

    def self.net_sales_for_period(first_week, last_week)
        net_sales = DispenserSalesNet.new(DispenserSalesTotal.initial_hash)
        sales_total_first_week = DispenserSalesTotal.new(first_week)
        sales_total_last_week = DispenserSalesTotal.new(last_week)
        DispenserSalesTotal.function_names.each do |function_name|
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

    def self.initial_hash
        hash = {}
        GRADES.each {|grade| hash[grade] = {'amount' => nil, 'gallons' => nil}}
        return hash
    end

    def self.function_names
        names = []
        GRADES.each do |grade|
            ['amount','gallons'].each {|column| names << grade + '.' + column}
        end
        return names
    end

    def total_by_grade(week)
        sales = week.dispenser_sales
        hash = DispenserSalesTotal.initial_hash
        hash['regular']['amount'] = sales.map{|e| e.regular}.sum
        hash['regular']['gallons'] = sales.map{|e| e.regular_volume}.sum.to_f
        hash['plus']['amount'] = sales.map{|e| e.plus}.sum
        hash['plus']['gallons'] = sales.map{|e| e.plus_volume}.sum.to_f
        hash['premium']['amount'] = sales.map{|e| e.premium}.sum
        hash['premium']['gallons'] = sales.map{|e| e.premium_volume}.sum.to_f
        hash['diesel']['amount'] = sales.map{|e| e.diesel}.sum
        hash['diesel']['gallons'] = sales.map{|e| e.diesel_volume}.sum.to_f
        return hash
    end
end
