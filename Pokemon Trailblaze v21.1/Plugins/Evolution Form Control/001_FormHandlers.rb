# Overwrite map-based form setting
if !EvolutionFormHandlingSettings::MAP_FORM_HANDLER_REMOVALS.empty?
	MultipleForms.register(EvolutionFormHandlingSettings::MAP_FORM_HANDLER_REMOVALS[0], {
	  "getForm" => proc { |pkmn| next }
	})

	MultipleForms.copy(*EvolutionFormHandlingSettings::MAP_FORM_HANDLER_REMOVALS) if EvolutionFormHandlingSettings::MAP_FORM_HANDLER_REMOVALS.length > 1
end

if !EvolutionFormHandlingSettings::ALOLAN_HELD_ITEM_FORM_1_HANDLER_POKEMON.empty?
	MultipleForms.register(EvolutionFormHandlingSettings::ALOLAN_HELD_ITEM_FORM_1_HANDLER_POKEMON[0], {
	  "getForm" => proc { |pkmn|
		next if pkmn.form_simple >= 2
		if pkmn.hasItem?(EvolutionFormHandlingSettings::ALOLAN_HELD_ITEM)
		  next 1
		end
		next 0
	  }
	})

	MultipleForms.copy(*EvolutionFormHandlingSettings::ALOLAN_HELD_ITEM_FORM_1_HANDLER_POKEMON) if EvolutionFormHandlingSettings::ALOLAN_HELD_ITEM_FORM_1_HANDLER_POKEMON.length > 1
end

if !EvolutionFormHandlingSettings::GALARIAN_HELD_ITEM_FORM_1_HANDLER_POKEMON.empty?
	MultipleForms.register(EvolutionFormHandlingSettings::GALARIAN_HELD_ITEM_FORM_1_HANDLER_POKEMON[0], {
	  "getForm" => proc { |pkmn|
		next if pkmn.form_simple >= 2
		if pkmn.hasItem?(EvolutionFormHandlingSettings::GALARIAN_HELD_ITEM)
		  next 1
		end
		next 0
	  }
	})

	MultipleForms.copy(*EvolutionFormHandlingSettings::GALARIAN_HELD_ITEM_FORM_1_HANDLER_POKEMON) if EvolutionFormHandlingSettings::GALARIAN_HELD_ITEM_FORM_1_HANDLER_POKEMON.length > 1
end

if !EvolutionFormHandlingSettings::HISUIAN_HELD_ITEM_FORM_1_HANDLER_POKEMON.empty?
	MultipleForms.register(EvolutionFormHandlingSettings::HISUIAN_HELD_ITEM_FORM_1_HANDLER_POKEMON[0], {
	  "getForm" => proc { |pkmn|
		next if pkmn.form_simple >= 2
		if pkmn.hasItem?(EvolutionFormHandlingSettings::HISUIAN_HELD_ITEM)
		  next 1
		end
		next 0
	  }
	})

	MultipleForms.copy(*EvolutionFormHandlingSettings::HISUIAN_HELD_ITEM_FORM_1_HANDLER_POKEMON) if EvolutionFormHandlingSettings::HISUIAN_HELD_ITEM_FORM_1_HANDLER_POKEMON.length > 1
end

if !EvolutionFormHandlingSettings::CUSTOM_HELD_ITEM_FORM_1_HANDLER_POKEMON.empty?
	MultipleForms.register(EvolutionFormHandlingSettings::CUSTOM_HELD_ITEM_FORM_1_HANDLER_POKEMON[0], {
	  "getForm" => proc { |pkmn|
		next if pkmn.form_simple >= 2
		if pkmn.hasItem?(EvolutionFormHandlingSettings::CUSTOM_HELD_ITEM_FORM_1)
		  next 1
		end
		next 0
	  }
	})

	MultipleForms.copy(*EvolutionFormHandlingSettings::CUSTOM_HELD_ITEM_FORM_1_HANDLER_POKEMON) if EvolutionFormHandlingSettings::CUSTOM_HELD_ITEM_FORM_1_HANDLER_POKEMON.length > 1
end

if !EvolutionFormHandlingSettings::CUSTOM_HELD_ITEM_FORM_2_HANDLER_POKEMON.empty?
	MultipleForms.register(EvolutionFormHandlingSettings::CUSTOM_HELD_ITEM_FORM_2_HANDLER_POKEMON[0], {
	  "getForm" => proc { |pkmn|
		next if pkmn.form_simple >= 2
		if pkmn.hasItem?(EvolutionFormHandlingSettings::CUSTOM_HELD_ITEM_FORM_2)
		  next 1
		end
		next 0
	  }
	})

	MultipleForms.copy(*EvolutionFormHandlingSettings::CUSTOM_HELD_ITEM_FORM_2_HANDLER_POKEMON) if EvolutionFormHandlingSettings::CUSTOM_HELD_ITEM_FORM_2_HANDLER_POKEMON.length > 1
end

# class PokemonEvolutionScene
  # alias _regional_evo_handling_after_evo pbEvolutionMethodAfterEvolution
  # def pbEvolutionMethodAfterEvolution
	# _regional_evo_handling_after_evo
    # if @pokemon.form > 0 && (([:RAICHU, :EXEGGUTOR, :MAROWAK].include?(@newspecies) && @pokemon.hasItem?(:ALOLANEVOITEM)) ||
			# ([:WEEZING, :MRMIME].include?(@newspecies) && @pokemon.hasItem?(:GALARIANEVOITEM)) || 
			# ([:THYPHLOSION, :SAMUROTT, :DECIDUEYE, :LILLIGANT, :BRAVIARY, :SLIGGOO, :AVALUGG].include?(@newspecies) && 
			# @pokemon.hasItem?(:HISUIANEVOITEM)))
      # @pokemon.item = nil
    # end
  # end
# end