#===============================================================================
# Wild Pokémon Item Sets
#===============================================================================
module WildItemSets
  CATEGORIES = [:offensive, :defensive, :utility, :extra]

  #---------------------------------------------------------------------------
	#	Module to define each pokemon's wild item sets
	#	Defined in this matter: Species => the
	#	:category (As my base, they are Offensive, Defensive, Utility and Extra)
	#	Each item inside of that hash must be an arrya in this format:
	#	[:ITEMID, minimum level for appearing, Max level, chance]
  #---------------------------------------------------------------------------
  SPECIES_SETS = {
    :PIKACHU => {
      :offensive => [
        [:LIGHTORB,     1, 100, 20],
        [:LIFEORB,     15, 100,  5],
        [:CHOICESCARF,  1,  70, 20],
        [:MAGNET,      20, 100, 95]
      ],
      :defensive => [
        [:HEAVYDUTYBOOTS, 20, 100, 30],
        [:ASSAULTVEST,     1,  70, 40],
        [:AIRBALLOON,     5, 100, 95]
      ],
      :utility => [
        [:LEFTOVERS,  1, 100, 90],
        [:ORANBERRY,  5,  30, 10]
      ]
    },

    :MAGIKARP => {
      :offensive => [
        [:MYSTICWATER, 1, 100, 30],
        [:DRAGONSCALE, 1, 100, 30]
      ],
      :utility => [
        [:LEFTOVERS, 1, 100, 90]
      ]
    }
  }

  #---------------------------------------------------------------------------
  # Type items behave the same, but they are type-generic instead of species-specific
  #---------------------------------------------------------------------------
  TYPE_ITEMS = {
    :WATER => {
      :defensive => [
        [:ASSAULTVEST, 1, 100, 80]
      ]
    },
    :FIRE => {
      :offensive => [
        [:CHARCOAL, 1, 100, 20]
      ]
    }
  }
end

#===============================================================================
# Wild Item Generation Logic
#===============================================================================
module WildItemGenerator
  module_function

  def apply_items(pkmn)
    return if pkmn.nil?
    used_categories = {}

    #-----------------------------------------------------------
    # Species-based items
    #-----------------------------------------------------------
    species_data = WildItemSets::SPECIES_SETS[pkmn.species]
    apply_set(pkmn, species_data, used_categories) if species_data

    #-----------------------------------------------------------
    # Type-based items
    #-----------------------------------------------------------
    pkmn.types.each do |type|
      type_data = WildItemSets::TYPE_ITEMS[type]
      apply_set(pkmn, type_data, used_categories) if type_data
    end
  end

  #-------------------------------------------------------------
  # Apply a full item set hash (species or type)
  #-------------------------------------------------------------
  def apply_set(pkmn, set_hash, used_categories)
    return if set_hash.nil?

    set_hash.each do |category, items|
      next if used_categories[category]
      try_give_item(pkmn, category, items, used_categories)
    end
  end

  #-------------------------------------------------------------
  # Try to give one valid item from a category
  #-------------------------------------------------------------
  def try_give_item(pkmn, category, items, used_categories)
    level = pkmn.level

    valid_items = items.select do |item, min, max, chance|
      level >= min && level <= max && rand(100) < chance
    end

    return if valid_items.empty?

    chosen_item = valid_items.sample.first
    return unless GameData::Item.exists?(chosen_item)

    pkmn.add_item(chosen_item)
    used_categories[category] = true
  end
end

#===============================================================================
# Hook into Wild Pokémon Generation
#===============================================================================
alias wilditems_pbGenerateWildPokemon pbGenerateWildPokemon
def pbGenerateWildPokemon(species, level, isRoamer = false)
  pkmn = wilditems_pbGenerateWildPokemon(species, level, isRoamer)
  WildItemGenerator.apply_items(pkmn)
  return pkmn
end

