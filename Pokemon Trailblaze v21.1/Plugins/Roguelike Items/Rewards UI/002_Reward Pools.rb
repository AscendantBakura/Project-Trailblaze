#-----------------------------------------------------------------------------
# Reward pool data class
#-----------------------------------------------------------------------------
module GameData
  class RewardPool
    attr_reader :id
    attr_reader :condition

    DATA = {}

    extend ClassMethodsSymbols
    include InstanceMethods

    RARITY_DATA.each_key do |rarity|
      attr_reader :"#{rarity}_pool"
    end

    def self.load; end
    def self.save; end

    def initialize(hash)
      @id        = hash[:id]
      @condition = hash[:condition]
      RARITY_DATA.each_key do |rarity|
        hash_key = rarity
        instance_var_name = :"@#{rarity}_pool"
        items = hash[hash_key] || []
        instance_variable_set(instance_var_name, items)
      end
    end

    def self.generate(count)
      rarity_data = Marshal.load(Marshal.dump(RARITY_DATA))
      if $game_temp.rarity_rules
        rarity_data.each_key do |rarity|
          rule_key = "itemRarity_#{rarity}"
          next if !$game_temp.rarity_rules.key?(rule_key)
          rarity_data[rarity][:chance] = $game_temp.rarity_rules[rule_key]
        end
        $game_temp.rarity_rules = {}
      end
      if $bag.has?(LUCKY_CHARM_ITEM_ID)
        ordered_rarities = RARITY_FALLBACK_ORDER.reverse
        luck_to_transfer = LUCKY_CHARM_STRENGTH.to_f
        (ordered_rarities.length - 1).times do |i|
          current_rarity = ordered_rarities[i]
          next_rarity    = ordered_rarities[i + 1]
          actual_shift = [luck_to_transfer, rarity_data[current_rarity][:chance]].min
          rarity_data[current_rarity][:chance] -= actual_shift
          rarity_data[next_rarity][:chance]    += actual_shift
        end
      end
      rarities = rarity_data.keys
      aggregated_pools = rarities.to_h { |r| [r, []] }
      GameData::RewardPool.each do |pool_data|
        result = (pool_data.condition) ? pool_data.condition.call : true
        next if !result
        rarities.each do |rarity|
          items = pool_data.public_send(:"#{rarity}_pool")
          aggregated_pools[rarity].concat(items)
        end
        next if !result.is_a?(Hash)
        result.each do |rarity, dynamic_items|
          next if !aggregated_pools.key?(rarity)
          items_to_add = [dynamic_items].flatten
          aggregated_pools[rarity].concat(items_to_add)
        end
      end
      aggregated_pools.each_value(&:uniq!)
      target_rarities = []
      total_weight = rarity_data.values.sum { |data| data[:chance] }
      if total_weight > 0
        count.times do
          roll = rand(1..total_weight)
          cumulative_weight = 0
          rarity_data.each do |rarity, data|
            cumulative_weight += data[:chance]
            if roll <= cumulative_weight
              target_rarities << rarity
              break
            end
          end
        end
      end
      fallback_order = RARITY_FALLBACK_ORDER
      target_rarities.sort_by! { |r| fallback_order.index(r) || fallback_order.length }
      results = []
      available_items = aggregated_pools.transform_values(&:shuffle)
      target_rarities.each do |target_rarity|
        item_found = nil
        actual_rarity = nil
        fallback_order.each do |rarity|
          next if rarity_is_rarer_than_target?(rarity, target_rarity, fallback_order)
          next if available_items[rarity].empty?
          item_found = available_items[rarity].pop
          next if !GameData::Item.exists?(item_found)
          actual_rarity = rarity
          break
        end
        if item_found.nil?
          fallback_order.each do |rarity|
            next if rarity_is_rarer_than_target?(rarity, target_rarity, fallback_order)
            next if aggregated_pools[rarity].empty?
            item_found = aggregated_pools[rarity].sample
            next if !GameData::Item.exists?(item_found)
            actual_rarity = rarity
            break
          end
        end
        results << [item_found, actual_rarity] if item_found
      end
      return results
    end

    def self.rarity_is_rarer_than_target?(rarity_to_check, target_rarity, order)
      (order.index(rarity_to_check) || -1) < (order.index(target_rarity) || -1)
    end
  end
end

#-----------------------------------------------------------------------------
# Display Reward UI in battle
#-----------------------------------------------------------------------------
class Battle
  unless method_defined?(:__roguelike__pbRecordAndStoreCaughtPokemon)
    alias __roguelike__pbRecordAndStoreCaughtPokemon pbRecordAndStoreCaughtPokemon
  end
  def pbRecordAndStoreCaughtPokemon(*args)
    __roguelike__pbRecordAndStoreCaughtPokemon(*args)
    return if [2, 5].include?(@decision)
    if RewardItemUI::REWARD_SCREEN_ENABLE_SWITCH > 0 && !$game_switches[RewardItemUI::REWARD_SCREEN_ENABLE_SWITCH]
      return
    end
    return if $game_temp.in_debug
    pbShowRewardsScreen
  end
end

alias __roguelike__pbDebugMenu pbDebugMenu unless defined?(__roguelike__pbDebugMenu)
def pbDebugMenu(*args)
  $game_temp.in_debug = true
  ret = __roguelike__pbDebugMenu(*args)
  $game_temp.in_debug = false
  return ret
end

class Game_Temp
  attr_accessor :in_debug
end

#-----------------------------------------------------------------------------
# Selector Sprite code
#-----------------------------------------------------------------------------
if !defined?(SelectorSprite)
  class SelectorSprite < Sprite
    attr_accessor :filename, :anchor, :speed

    #---------------------------------------------------------------------------
    #  initializes sprite sheet
    #---------------------------------------------------------------------------
    def initialize(viewport, frames = 1)
      @frames     = frames
      self.speed  = 0.15
      @frame_time = System.uptime
      @vertical   = false
      super(viewport)
    end

    #---------------------------------------------------------------------------
    #  sets sheet bitmap
    #---------------------------------------------------------------------------
    def render(rect, file = nil, vertical = false)
      @filename       = file if @filename.nil? && !file.nil?
      @frame_time     = 0
      self.src_rect.x = 0
      self.src_rect.y = 0
      self.set_bitmap(sel_bmp(@filename, rect), vertical)
      self.ox = self.src_rect.width / 2
      self.oy = self.src_rect.height / 2
    end

    #---------------------------------------------------------------------------
    #  target sprite with selector
    #---------------------------------------------------------------------------
    def target(sprite, offset = 0)
      return if !sprite || !sprite.respond_to?(:bitmap)
      self.render(Rect.new(0, 0, sprite.src_rect.width - offset, sprite.src_rect.height - offset))
      self.anchor = sprite
      update
    end

    #---------------------------------------------------------------------------
    #  sets sheet bitmap
    #---------------------------------------------------------------------------
    def set_bitmap(file, vertical = false)
      self.bitmap = (file.is_a?(Bitmap)) ? file : RPG::Cache.load_bitmap("", file)
      @vertical = vertical
      if @vertical
        self.src_rect.height /= @frames
      else
        self.src_rect.width /= @frames
      end
    end

    #---------------------------------------------------------------------------
    #  update sprite
    #---------------------------------------------------------------------------
    def update
      return if !self.bitmap
      if (System.uptime - @frame_time) >= @speed
        if @vertical
          self.src_rect.y += self.src_rect.height
          self.src_rect.y = 0 if self.src_rect.y >= self.bitmap.height
        else
          self.src_rect.x += self.src_rect.width
          self.src_rect.x = 0 if self.src_rect.x >= self.bitmap.width
        end
        @frame_time = System.uptime
      end
      return if !self.anchor || self.anchor.disposed?
      self.x       = self.anchor.x - self.anchor.ox + (self.anchor.src_rect.width / 2)
      self.y       = self.anchor.y - self.anchor.oy + (self.anchor.src_rect.height / 2) - 2
      self.z       = self.anchor.z + 1
      self.opacity = self.anchor.opacity
      self.visible = self.anchor.visible
    end

    #---------------------------------------------------------------------------
    def sel_bmp(name, rect)
      bmp = RPG::Cache.load_bitmap("", name)
      qw = bmp.width / 2
      qh = bmp.height / 2
      max_w = rect.width + (qw * 2) - 8
      max_h = rect.height + (qh * 2) - 8
      full = Bitmap.new(max_w * 4, max_h)
      # draws 4 frames where corners of selection get closer to bounding rect
      4.times do |i|
        4.times do |j|
          m = (i < 3) ? i : (i - 2)
          x = (((j.even?) ? 2 : -2) * m) + (max_w * i) + ((j.even?) ? 0 : max_w - qw)
          y = (((j / 2 == 0) ? 2 : -2) * m) + ((j / 2 == 0) ? 0 : max_h - qh)
          full.blt(x, y, bmp, Rect.new(qw * (j % 2), qh * (j / 2), qw, qh))
        end
      end
      return full
    end
    #---------------------------------------------------------------------------
  end
end
