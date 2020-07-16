class HashDataModel
  attr_accessor   :_columns

  def initialize(hash)
    @_columns = []
    build(hash)
  end

  def to_hash
    hash = {}
    self._columns.each do |column|
      value = self.instance_variable_get("@#{column}")
      if value.is_a?(HashDataModel)
        hash[column] = value.to_hash
      elsif value.is_a?(Array)
        hash[column] = []
        value.each do |data|
          hash[column] << (data.kind_of?(HashDataModel) ? data.to_hash : data)
        end
      else
        hash[column] = value
      end
    end
    return hash
  end

  def self.collection_to_array(collection)
    array = []
    collection.each do |object|
      raise "object must be a HashDataModel object" unless object.is_a?(HashDataModel)
      array << object.to_hash
    end
    return array
  end

  def merge(hash)
    build(hash)
  end

  private

  def build(hash)
    hash.each do |key,value|
      if key.is_a?(String)
        key_name = key
      elsif key.is_a?(Integer) or key.is_a?(Symbol)
        key_name = key.to_s
      else
        raise "hash keys must be a String" unless key.is_a?(String)
      end
      @_columns << key_name
      if value.is_a?(Array)
        field_value = ArrayClass.new(value).collection
      elsif value.is_a?(Hash)
        field_value = HashDataModel.new(value)
      elsif value.is_a?(HashDataModel)
        field_value = value
      else
        field_value = value
      end
      singleton_class.class_eval { attr_accessor key_name }
      self.instance_variable_set("@#{key_name}", field_value)
    end
  end

  class ArrayClass
    attr_accessor   :collection
    def initialize(array)
      @collection = []
      array.each do |row|
        if row.is_a?(HashDataModel)
          collection << row
        elsif row.class.name == 'Hash'
          collection << HashDataModel.new(row)
        else
          collection << row
        end
      end
    end
  end

end
