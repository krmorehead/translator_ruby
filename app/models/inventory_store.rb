# frozen_string_literal: true

# File-backed inventory store handling serialization and basic operations.
class InventoryStore
  attr_reader :path

  def initialize(path:)
    @path = path
    @items = load_items
  end

  def all_items
    @items
  end

  def find_item(name)
    @items.find { |i| i.name.downcase == name.downcase }
  end

  def add_or_update_item(item)
    existing = find_item(item.name)
    if existing
      new_qty = existing.quantity + item.quantity
      raise ArgumentError, "quantity must be >= 0" if new_qty < 0
      replace_item(existing.name, existing.with_quantity(new_qty))
    else
      @items << item
    end
    save!
    item
  end

  def update_quantity(name, quantity)
    raise ArgumentError, "quantity must be >= 0" if quantity.to_i < 0
    existing = find_item(name)
    raise ArgumentError, "item not found" unless existing

    replace_item(existing.name, existing.with_quantity(quantity.to_i))
    save!
  end

  def remove_item(name)
    before = @items.length
    @items.reject! { |i| i.name.downcase == name.downcase }
    save! if @items.length != before
  end

  def to_a
    @items.map(&:to_h)
  end

  private

  def load_items
    return [] unless File.exist?(path)

    data = JSON.parse(File.read(path), symbolize_names: true)
    (data || []).map { |h| InventoryItem.from_h(h) }
  end

  def save!
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(to_a))
  end

  def replace_item(name, new_item)
    @items.map! do |i|
      i.name.downcase == name.downcase ? new_item : i
    end
  end
end
