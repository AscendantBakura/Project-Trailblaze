
# Regional Form Evolution Methods
GameData::Evolution.register({
  :id            => :LevelFormOne,
  :parameter     => Integer,
  :level_up_proc => proc { |pkmn, parameter|
    if pkmn.level >= parameter
		pkmn.form = 1 
		next true
	end
	next false
  }
})
GameData::Evolution.register({
  :id            => :LevelFormTwo,
  :parameter     => Integer,
  :level_up_proc => proc { |pkmn, parameter|
    if pkmn.level >= parameter
		pkmn.form = 2 
		next true
	end
	next false
  }
})

GameData::Evolution.register({
  :id            => :LevelAlolanItem,
  :parameter     => Integer,
  :level_up_proc => proc { |pkmn, parameter|
    if pkmn.level >= parameter && pkmn.item == EvolutionFormHandlingSettings::ALOLAN_LEVEL_UP_ITEM
		pkmn.form = 1
		next true
	end
	next false
  },
  :after_evolution_proc => proc { |pkmn, new_species, parameter, evo_species|
    next false if evo_species != new_species || !pkmn.hasItem?(EvolutionFormHandlingSettings::ALOLAN_LEVEL_UP_ITEM)
    pkmn.item = nil unless pkmn.form != 1
    next true
  }
})

GameData::Evolution.register({
  :id            => :LevelGalarianItem,
  :parameter     => Integer,
  :level_up_proc => proc { |pkmn, parameter|
    if pkmn.level >= parameter && pkmn.item == EvolutionFormHandlingSettings::GALARIAN_LEVEL_UP_ITEM
		pkmn.form = 1
		next true
	end
	next false
  },
  :after_evolution_proc => proc { |pkmn, new_species, parameter, evo_species|
    next false if evo_species != new_species || !pkmn.hasItem?(EvolutionFormHandlingSettings::GALARIAN_LEVEL_UP_ITEM)
    pkmn.item = nil unless pkmn.form != 1
    next true
  }
})

GameData::Evolution.register({
  :id            => :LevelHisuianItem,
  :parameter     => Integer,
  :level_up_proc => proc { |pkmn, parameter|
    if pkmn.level >= parameter && pkmn.item == EvolutionFormHandlingSettings::HISUIAN_LEVEL_UP_ITEM
		pkmn.form = 1 
		next true
	end
	next false
  },
  :after_evolution_proc => proc { |pkmn, new_species, parameter, evo_species|
    next false if evo_species != new_species || !pkmn.hasItem?(EvolutionFormHandlingSettings::HISUIAN_LEVEL_UP_ITEM)
    pkmn.item = nil unless pkmn.form != 1
    next true
  }
})

GameData::Evolution.register({
  :id            => :LevelCustomForm1Item,
  :parameter     => Integer,
  :level_up_proc => proc { |pkmn, parameter|
    if pkmn.level >= parameter && pkmn.item == EvolutionFormHandlingSettings::CUSTOM_LEVEL_UP_ITEM_FORM_1
		pkmn.form = 1 
		next true
	end
	next false
  },
  :after_evolution_proc => proc { |pkmn, new_species, parameter, evo_species|
    next false if evo_species != new_species || !pkmn.hasItem?(EvolutionFormHandlingSettings::CUSTOM_LEVEL_UP_ITEM_FORM_1)
    pkmn.item = nil unless pkmn.form != 1
    next true
  }
})

GameData::Evolution.register({
  :id            => :LevelCustomForm2Item,
  :parameter     => Integer,
  :level_up_proc => proc { |pkmn, parameter|
    if pkmn.level >= parameter && pkmn.item == EvolutionFormHandlingSettings::CUSTOM_LEVEL_UP_ITEM_FORM_2
		pkmn.form = 2 
		next true
	end
	next false
  },
  :after_evolution_proc => proc { |pkmn, new_species, parameter, evo_species|
    next false if evo_species != new_species || !pkmn.hasItem?(EvolutionFormHandlingSettings::CUSTOM_LEVEL_UP_ITEM_FORM_2)
    pkmn.item = nil unless pkmn.form != 2
    next true
  }
})

# Generic Form Evolution Methods

# Hold Item On Level
GameData::Evolution.register({
  :id                   => :HoldItemFormOne,
  :parameter            => :Item,
  :any_level_up         => true,   # Needs any level up
  :level_up_proc        => proc { |pkmn, parameter|
	if pkmn.item == parameter
		pkmn.form = 1
		next true
	end
    next false
  },
  :after_evolution_proc => proc { |pkmn, new_species, parameter, evo_species|
    next false if evo_species != new_species || !pkmn.hasItem?(parameter)
    pkmn.item = nil   # Item is now consumed
    next true
  }
})

GameData::Evolution.register({
  :id                   => :HoldItemFormTwo,
  :parameter            => :Item,
  :any_level_up         => true,   # Needs any level up
  :level_up_proc        => proc { |pkmn, parameter|
	if pkmn.item == parameter
		pkmn.form = 2
		next true
	end
    next false
  },
  :after_evolution_proc => proc { |pkmn, new_species, parameter, evo_species|
    next false if evo_species != new_species || !pkmn.hasItem?(parameter)
    pkmn.item = nil   # Item is now consumed
    next true
  }
})

# Use Item/Evo Stones
GameData::Evolution.register({
  :id            => :ItemFormOne,
  :parameter     => :Item,
  :use_item_proc => proc { |pkmn, parameter, item|
    if item == parameter
		pkmn.form = 1
		next true
	end
	next false
  }
})

GameData::Evolution.register({
  :id            => :ItemFormTwo,
  :parameter     => :Item,
  :use_item_proc => proc { |pkmn, parameter, item|
    if item == parameter
		pkmn.form = 2
		next true
	end
	next false
  }
})

# Has Move
GameData::Evolution.register({
  :id            => :HasMoveFormOne,
  :parameter     => :Move,
  :any_level_up  => true,   # Needs any level up
  :level_up_proc => proc { |pkmn, parameter|
    if pkmn.moves.any? { |m| m && m.id == parameter }
		pkmn.form = 1
		next true
	end
	next false
  }
})

GameData::Evolution.register({
  :id            => :HasMoveFormTwo,
  :parameter     => :Move,
  :any_level_up  => true,   # Needs any level up
  :level_up_proc => proc { |pkmn, parameter|
    if pkmn.moves.any? { |m| m && m.id == parameter }
		pkmn.form = 2
		next true
	end
	next false
  }
})