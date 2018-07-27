class HashManager
  attr_accessor   :_columns

  def initialize(hash, other_accessors = nil)
    unless other_accessors.nil?
      other_accessors.each do |key, value|
        singleton_class.class_eval { attr_accessor key }
        self.instance_variable_set("@#{key}", value)
      end
    end

    @_columns = []
    hash.each do |key,value|
      if key.is_a?(String)
        key_name = key
      elsif key.is_a?(Fixnum) or key.is_a?(Symbol)
        key_name = key.to_s
      else
        raise "hash keys must be a String" unless key.is_a?(String)
      end
      @_columns << key_name
      if value.is_a?(Array)
        field_value = ArrayClass.new(value).collection
      elsif value.is_a?(Hash)
        field_value = HashManager.new(value)
      elsif value.is_a?(HashManager)
        field_value = value
      #elsif value.is_a?(String) and value.include?("__DateTime__:")
      #  value.slice!("__DateTime__:")
      #  field_value = DateTime.parse(value)
      #elsif value.is_a?(String) and value.include?("__Date__:")
      #  value.slice!("__Date__:")
      #  field_value = Date.parse(value)
      else
        field_value = value
      end
      singleton_class.class_eval { attr_accessor key_name }
      self.instance_variable_set("@#{key_name}", field_value)
    end
  end

  def get_key(key_name)
    self.instance_variable_get("@#{key_name}")
  end

  def set_value(accessor, value)
    columns = accessor.split('.')
    column = columns.pop
    container = self
    columns.each {|c| container = container.instance_variable_get("@#{c}")}
    container.instance_variable_set("@#{column}", value)
  end

  def get_value(accessor)
    columns = accessor.split('.')
    value = self
    columns.each {|column| value = value.instance_variable_get("@#{column}")}
    return value
  end

  def matches?(hash)
    hash.each do |key,value|
      key_name = key.is_a?(Symbol) ? key.to_s : key
      if value.is_a?(Array)
        return false unless value.include?(self.get_key(key_name))
      else
        return false unless self.get_key(key_name) == value
      end
    end
    return true
  end

  def to_hash
    hash = {}
    self._columns.each do |column|
      value = self.instance_variable_get("@#{column}")
      if value.is_a?(HashManager)
        hash[column] = value.to_hash
      elsif value.is_a?(Array)
        hash[column] = []
        value.each do |data|
          hash[column] << (data.kind_of?(HashManager) ? data.to_hash : data)
        end
      #elsif value.is_a?(DateTime)
      #  hash[column] = "__DateTime__:" + value.to_s
      #elsif value.is_a?(Date)
      #  hash[column] = "__Date__:" + value.to_s
      else
        hash[column] = value
      end
    end
    return hash
  end

  def self.collection_to_array(collection)
    array = []
    collection.each do |object|
      raise "object must be a HashManager object" unless object.is_a?(HashManager)
      array << object.to_hash
    end
    return array
  end

  class ArrayClass
    attr_accessor   :collection
    def initialize(array)
      @collection = []
      array.each do |row|
        if row.is_a?(HashManager)
          collection << row
        elsif row.class.name == 'Hash'
          collection << HashManager.new(row)
        else
          collection << row
        end
      end
    end
  end

end
