# frozen_string_literal: true

# Model representing a single inventory item.
class InventoryItem
  ATTRIBUTES = %i[name weight description property_type quantity].freeze

  attr_reader :name, :weight, :description, :property_type, :quantity

  def initialize(name:, weight:, description:, property_type:, quantity: 1)
    raise ArgumentError, "name required" if name.to_s.strip.empty?
    raise ArgumentError, "quantity must be >= 0" if quantity.to_i < 0

    @name = name
    @weight = weight
    @description = description
    @property_type = property_type
    @quantity = quantity.to_i
  end

  def to_h
    attributes
  end

  def self.from_h(hash)
    new(
      name: hash[:name] || hash["name"],
      weight: hash[:weight] || hash["weight"],
      description: hash[:description] || hash["description"],
      property_type: hash[:property_type] || hash["property_type"],
      quantity: hash[:quantity] || hash["quantity"]
    )
  end

  def with_quantity(new_quantity)
    self.class.new(
      name: name,
      weight: weight,
      description: description,
      property_type: property_type,
      quantity: new_quantity
    )
  end

  # Fetch an attribute by symbol or string key (e.g., item[:name] or item["name"])
  def [](key)
    case key.to_sym
    when :name then name
    when :weight then weight
    when :description then description
    when :property_type then property_type
    when :quantity then quantity
    else
      nil
    end
  end

  # Return a hash of attributes with symbol keys
  def attributes
    {
      name: name,
      weight: weight,
      description: description,
      property_type: property_type,
      quantity: quantity
    }
  end

  def as_json(*)
    attributes
  end

  def to_json(*args)
    attributes.to_json(*args)
  end
end
