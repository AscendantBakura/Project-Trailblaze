module HackingGameSettings
    #===========================================================================
    #=============================== Settings ==================================
    #===========================================================================
    
	#---------------------------------------------------------------------------
	#  Set the colors of the text that appears on the border of a hacking  
	#  minigame (timer, move count, Edit Mode help).
	#  Format: [Base Color, Shadow Color]
	#---------------------------------------------------------------------------	
	BORDER_TEXT_COLORS = [Color.new(240, 248, 224), Color.new(64, 64, 64)]

	#---------------------------------------------------------------------------
	#  Set the style of the timer. 
	#  1 = Bar only, 2 = Text Only, 3 = Both
	#---------------------------------------------------------------------------	
	TIMER_TYPE = 1 

	#---------------------------------------------------------------------------
	#  If true, players must always use the Use button to interact with a node. 
	#  If false, they will interact with a node as soon as they touch it.
	#---------------------------------------------------------------------------
	MUST_PRESS_BUTTON_TO_START_PUZZLES = false

	#---------------------------------------------------------------------------
	#  If true, an indicator will appear if the player can interact with the 
	#  node they are currently on. It's recommended that this is set to true if
	#  MUST_PRESS_BUTTON_TO_START_PUZZLES is set to true.
	#---------------------------------------------------------------------------	
	SHOW_INTERACT_INDICATOR = false

	#---------------------------------------------------------------------------
	#  Define what BGM will be used by default during a hacking minigame.
	#---------------------------------------------------------------------------	
	DEFAULT_BGM = _INTL("Game Corner")

	#---------------------------------------------------------------------------
	#  Define a message that will appear when the player starts a hacking 
    #  minigame. This can be a single string, or an array of strings to appear 
    #  in a row. Set to "" or nil to not show any message.
	#---------------------------------------------------------------------------	
	DEFAULT_START_MESSAGE = nil

	#---------------------------------------------------------------------------
	#  Define a message that will appear when the player wins a hacking 
    #  minigame. This can be a single string, or an array of strings to appear 
    #  in a row. Set to "" to not show any message.
	#---------------------------------------------------------------------------	
	DEFAULT_WIN_MESSAGE = _INTL("Winner!")

	#---------------------------------------------------------------------------
	#  Define the options for Fog of War (reduces visibility). The center of
	#  these graphics will always align with the player.
	#  Defaults to _INTL("Graphics/UI/Hacking Game/fog") if nothing is defined.
	#  Format: :key => [Name (when selecting in Edit Mode), File Path]
	#---------------------------------------------------------------------------	
	FOG_OF_WAR_SIZES = {
		:large => [_INTL("Large"), _INTL("Graphics/UI/Hacking Game/fog")],
		:small => [_INTL("Small"), _INTL("Graphics/UI/Hacking Game/fog_small")],
	}

	#---------------------------------------------------------------------------
	#  Set the filepath where games will be exported to and imported from.
    #  The path must end with a "/".
	#---------------------------------------------------------------------------	
	GAME_FILEPATH = _INTL("Plugins/Hacking Minigame/Games/")

end