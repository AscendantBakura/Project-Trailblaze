module EvolutionFormHandlingSettings
	#====================================================================================
    #============================= Remove Map Requirement ===============================
    #====================================================================================
	# This is used to remove the requirement to be on a map in a specific region for 
	# regional evolutions. You can remove Pokemon from this list if you want them to keep 
	# this requirement.
	
	MAP_FORM_HANDLER_REMOVALS = [:PIKACHU, :EXEGGCUTE, :CUBONE, :KOFFING, :MIMEJR, 
		:QUILAVA, :DEWOTT, :DARTRIX, :PETILIL, :RUFFLET, :GOOMY, :BERGMITE]
	
	#====================================================================================
    #============================= Forced Form Held Items ===============================
    #====================================================================================
	# Pokemon listed in the following XX_HANDLER_POKEMON arrays will not respect form 
	# changes in Evolution methods included in this plugin. Instead, it will make the 
	# Pokemon always be a set Form if it's holding the items set in the associated 
	# XX_HELD_ITEM, and should have regular evolution methods set in their Form X 
	# definition in pokemon_forms.txt if different than their base form's evolution 
	# method. (See Setup and Documentation guide for more details)
	
	# Alolan Form 1
	ALOLAN_HELD_ITEM = :HEATROCK
	ALOLAN_HELD_ITEM_FORM_1_HANDLER_POKEMON = []
	
	# Galarian Form 1
	GALARIAN_HELD_ITEM = :DAMPROCK
	GALARIAN_HELD_ITEM_FORM_1_HANDLER_POKEMON = []
	
	# Hisuian Form 1
	HISUIAN_HELD_ITEM = :ICYROCK
	HISUIAN_HELD_ITEM_FORM_1_HANDLER_POKEMON = []
	
	# Custom Form 1
	CUSTOM_HELD_ITEM_FORM_1 = :FLAMEORB
	CUSTOM_HELD_ITEM_FORM_1_HANDLER_POKEMON = []
	
	# Custom Form 2
	CUSTOM_HELD_ITEM_FORM_2 = :LIFEORB
	CUSTOM_HELD_ITEM_FORM_2_HANDLER_POKEMON = []
	
	#====================================================================================
    #============================== Level Up Held Items =================================
    #====================================================================================
	# Define the items that are used by some of the level up evolution methods provided  
	# by this plugin.
	
	# Used by LevelAlolanItem
	ALOLAN_LEVEL_UP_ITEM = :HEATROCK
	
	# Used by LevelGalarianItem
	GALARIAN_LEVEL_UP_ITEM = :DAMPROCK
	
	# Used by LevelHisuianItem
	HISUIAN_LEVEL_UP_ITEM = :ICYROCK
	
	# Used by LevelCustomForm1Item
	CUSTOM_LEVEL_UP_ITEM_FORM_1 = :FLAMEORB
	
	# Used by LevelCustomForm2Item
	CUSTOM_LEVEL_UP_ITEM_FORM_2 = :LIFEORB
	
end

