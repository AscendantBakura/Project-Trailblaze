#-------------------------------------------------------------------------------
# Multiple item main code
#-------------------------------------------------------------------------------
class Pokemon
  attr_reader :items

  alias __roguelike__initialize initialize unless private_method_defined?(:__roguelike__initialize)
  def initialize(*args)
    __roguelike__initialize(*args)
    @items = []
  end

  def add_item(item)
    return nil if !GameData::Item.exists?(item)
    return nil if items_full?
    @items.push(GameData::Item.get(item).id)
    return item
  end

  def remove_item(item = nil)
    return nil if items_empty?
    target_item = item || @items.last
    return nil unless GameData::Item.exists?(target_item)
    item_idx = @items.index(GameData::Item.get(target_item).id)
    return (item_idx) ? @items.delete_at(item_idx) : nil
  end

  def each_item
    @items.each { |i| yield GameData::Item.try_get(i) }
  end

  def item_count; return @items.size; end

  def items_full?; return item_count == MAX_ITEM_COUNT; end

  def items_empty?; return item_count == 0; end

  def item_id
    return nil if items_empty?
    return GameData::Item.get(@items.last).id
  end

  def item
    return nil if items_empty?
    return GameData::Item.get(@items.last)
  end

  def item=(value)
    (!value || !GameData::Item.exists?(value)) ? remove_item : add_item(value)
  end

  def hasItem?(check_item = nil)
    if check_item.nil?
      return !items_empty?
    else
      check_item = GameData::Item.get(check_item).id
      each_item { |item| return true if item && item.id == check_item }
    end
    return false
  end
end

#-------------------------------------------------------------------------------
# Give multiple item to trainer battles
#-------------------------------------------------------------------------------
class GameData::Trainer
  class << self
    alias __roguelike__sub_schema sub_schema unless method_defined?(:__roguelike__sub_schema)
  end
  def self.sub_schema
    ret = __roguelike__sub_schema
    ret["Item"] = [:item, "*e", :Item]
    return ret
  end

  alias __roguelike__to_trainer to_trainer unless method_defined?(:__roguelike__to_trainer)
  def to_trainer(*args)
    old_items = []
    @pokemon.each_with_index do |pkmn_data, i|
      old_items[i] = pkmn_data[:item].clone if pkmn_data[:item]
      @pokemon[i][:item] = nil
    end
    ret = __roguelike__to_trainer(*args)
    ret.party.each_with_index do |pkmn, i|
      old_items[i]&.each { |item| pkmn.add_item(item) }
      @pokemon[i][:item] = old_items[i]
    end
    return ret
  end
end
