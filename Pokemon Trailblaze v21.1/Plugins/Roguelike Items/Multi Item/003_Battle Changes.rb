#-----------------------------------------------------------------------------
# All battler changes for multi items
#-----------------------------------------------------------------------------
class Battle::Battler
  attr_accessor :display_item

  alias __roguelike__pbInitPokemon pbInitPokemon unless method_defined?(:__roguelike__pbInitPokemon)
  def pbInitPokemon(pkmn, idxParty)
    __roguelike__pbInitPokemon(pkmn, idxParty)
    @items = nil
  end

  def items
    @items = pokemon.items.clone if !@items
    return @items
  end

  def add_item(item)
    return nil if !GameData::Item.exists?(item)
    return nil if items_full?
    items.push(GameData::Item.get(item).id)
    return item
  end

  def remove_item(item = nil)
    return nil if items_empty?
    target_item = item || items.last
    return nil unless GameData::Item.exists?(target_item)
    item_idx = items.index(GameData::Item.get(target_item).id)
    return (item_idx) ? items.delete_at(item_idx) : nil
  end

  def each_item
    items.each { |i| yield GameData::Item.try_get(i) }
  end

  def item_count; return items.size; end

  def items_full?; return item_count == Pokemon::MAX_ITEM_COUNT; end

  def items_empty?; return item_count == 0; end

  def item_id
    return nil if items_empty?
    return GameData::Item.get(display_item || items.last).id
  end

  def item
    return nil if items_empty?
    return GameData::Item.get(display_item || items.last)
  end

  def item=(value)
    (!value || !GameData::Item.exists?(value)) ? remove_item : add_item(value)
  end

  def hasActiveItem?(check_item, ignore_fainted = false)
    self.display_item = nil
    return false if !itemActive?(ignore_fainted)
    each_item do |item|
      if check_item.is_a?(Array)
        next if !check_item.include?(item.id)
      else
        next if item.id != check_item
      end
      self.display_item = item
      return true
    end
    return false
  end

  def losable_items
    items = []
    each_item { |i| items.push(i.id) if !unlosableItem?(i) }
    return items
  end

  def lost_item?
    return items.size < self.pokemon.items.size
  end

  def item_names_formatted
    item_names = items.map { |item_id| GameData::Item.get(item_id).name }
    formatted_list = ""
    if !item_names.empty?
      if item_names.length == 1
        formatted_list = item_names[0]
      elsif item_names.length == 2
        formatted_list = item_names.join(_INTL(" and "))
      else
        last_item = item_names.pop
        formatted_list = item_names.join(_INTL(", ")) + _INTL(" and ") + last_item
      end
    end
    return formatted_list
  end

  def has_initial_item?(item)
    return false if !self.pokemon
    return self.pokemon.hasItem?(item)
  end

  def set_initial_item(new_item, old_item = nil)
    return if !self.pokemon
    self.pokemon.remove_item(old_item) if old_item && self.pokemon.items_full?
    self.pokemon.item = new_item if !new_item.nil?
  end

  def setInitialItem(new_item)
    set_initial_item(new_item, nil)
  end

  def initialItem; return nil; end

  alias __roguelike__pbEndTurn pbEndTurn unless method_defined?(:__roguelike__pbEndTurn)
  def pbEndTurn(*args)
    __roguelike__pbEndTurn(*args)
    self.display_item = nil
  end

  def pbRemoveItem(permanent = true, item: nil)
    item ||= self.item
    return if !item
    @effects[PBEffects::ChoiceBand] = nil if [:CHOICEBAND, :CHOICESPECS, :CHOICESCARF].include?(item)
    @effects[PBEffects::Unburden]   = true if hasActiveAbility?(:UNBURDEN)
    set_initial_item(nil, item) if permanent && has_initial_item?(item)
    remove_item(item)
  end

  def pbConsumeItem(recoverable = true, symbiosis = true, belch = true, item: nil)
    item ||= self.item
    return if !item
    item = @effects[PBEffects::GemConsumed] if @effects[PBEffects::GemConsumed]
    item_id = GameData::Item.get(item).id
    PBDebug.log("[Item consumed] #{pbThis} consumed its held #{itemName}")
    if recoverable
      setRecycleItem(item_id)
      @effects[PBEffects::PickupItem] = item_id
      @effects[PBEffects::PickupUse]  = @battle.nextPickupUse
    end
    setBelched if belch && GameData::Item.get(item_id).is_berry?
    pbRemoveItem(item: item_id)
    pbSymbiosis if symbiosis
  end

  def pbSymbiosis
    return if fainted?
    return if items_full?
    @battle.pbPriority(true).each do |b|
      next if b.opposes?(self)
      next if !b.hasActiveAbility?(:SYMBIOSIS)
      next if b.items_empty? || b.losable_items.empty?
      item_data = GameData::Item.get(b.losable_items.sample).id
      next if unlosableItem?(item_data.id) || b.unlosableItem?(item_data.id)
      item_name = item_data.name
      @battle.pbShowAbilitySplash(b)
      if Battle::Scene::USE_ABILITY_SPLASH
        @battle.pbDisplay(_INTL("{1} shared its {2} with {3}!",
                                b.pbThis, item_name, pbThis(true)))
      else
        @battle.pbDisplay(_INTL("{1}'s {2} let it share its {3} with {4}!",
                                b.pbThis, b.abilityName, item_name, pbThis(true)))
      end
      self.item = item_data.id
      b.remove_item(item_data.id)
      b.effects[PBEffects::Unburden] = true if b.hasActiveAbility?(:UNBURDEN)
      @battle.pbHideAbilitySplash(b)
      pbHeldItemTriggerCheck
      break
    end
  end

  def pbMoveTypePoweringUpGem(gem_type, move, move_type, mults)
    return if move.is_a?(Battle::Move::PledgeMove)
    return if move_type != gem_type
    @effects[PBEffects::GemConsumed] = display_item
    if Settings::MECHANICS_GENERATION >= 6
      mults[:power_multiplier] *= 1.3
    else
      mults[:power_multiplier] *= 1.5
    end
  end
end

#-----------------------------------------------------------------------------
# All battle related changes for setting items
#-----------------------------------------------------------------------------
class Battle
  alias __roguelike__initialize initialize unless private_method_defined?(:__roguelike__initialize)
  def initialize(*args)
    __roguelike__initialize(*args)
    @initialItems = [
      Array.new(@party1.length) { |i| next nil },
      Array.new(@party2.length) { |i| next nil }
    ]
  end

  alias __roguelike__pbStorePokemon pbStorePokemon unless method_defined?(:__roguelike__pbStorePokemon)
  def pbStorePokemon(*args)
    ret = __roguelike__pbStorePokemon(*args)
    @initialItems = [
      Array.new(@party1.length) { |i| next nil },
      Array.new(@party2.length) { |i| next nil }
    ]
    return ret
  end

  alias __roguelike__pbEndOfBattle pbEndOfBattle unless method_defined?(:__roguelike__pbEndOfBattle)
  def pbEndOfBattle(*args)
    old_items = []
    pbParty(0).each_with_index do |pkmn, i|
      old_items[i] = pkmn.item if pkmn
    end
    ret = __roguelike__pbEndOfBattle(*args)
    pbParty(0).each_with_index do |pkmn, i|
      pkmn&.add_item(old_items[i])
    end
    return ret
  end

  alias __roguelike__pbEndOfRoundPhase pbEndOfRoundPhase unless method_defined?(:__roguelike__pbEndOfRoundPhase)
  def pbEndOfRoundPhase(*args)
    __roguelike__pbEndOfRoundPhase(*args)
    eachBattler { |battler| battler.display_item = nil }
  end

  alias __roguelike__pbMegaEvolve pbMegaEvolve unless method_defined?(:__roguelike__pbMegaEvolve)
  def pbMegaEvolve(*args)
    battler = @battlers[args[0]]
    mega_stone = nil
    GameData::Species.each do |data|
      next if data.species != battler.pokemon.species || data.unmega_form != battler.pokemon.form_simple
      next if !data.mega_stone || !battler.pokemon.hasItem?(data.mega_stone)
      mega_stone = data.mega_stone
      break
    end
    battler&.display_item = mega_stone if mega_stone
    __roguelike__pbMegaEvolve(*args)
    battler&.display_item = nil
  end
end

#-----------------------------------------------------------------------------
# All Battle rule related changes
#-----------------------------------------------------------------------------
class Game_Temp
  attr_accessor :rarity_rules

  alias __roguelike__add_battle_rule add_battle_rule unless method_defined?(:__roguelike__add_battle_rule)
  def add_battle_rule(*args)
    if args[0].include?("itemRarity_") && args[1].is_a?(Numeric)
      @rarity_rules = {} if !@rarity_rules
      @rarity_rules[args[0]] = args[1]
    else
      __roguelike__add_battle_rule(*args)
    end
  end
end

alias __roguelike__setBattleRule setBattleRule unless defined?(__roguelike__setBattleRule)
def setBattleRule(*args)
  if args[0].include?("itemRarity_")
    $game_temp.add_battle_rule(args[0], args[1])
  else
    __roguelike__setBattleRule(*args)
  end
end
