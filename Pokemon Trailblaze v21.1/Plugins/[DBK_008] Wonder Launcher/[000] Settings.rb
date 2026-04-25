#===============================================================================
# Settings.
#===============================================================================
module Settings
  #-----------------------------------------------------------------------------
  # Stores the path name for the graphics utilized by this plugin.
  #-----------------------------------------------------------------------------
  WONDER_LAUNCHER_PATH = "Graphics/Plugins/Wonder Launcher/"
  
  #-----------------------------------------------------------------------------
  # The switch number used to enable the Wonder Launcher for trainer battles.
  # When turned on, all trainer battles will utilize the Wonder Launcher by default.
  #-----------------------------------------------------------------------------
  WONDER_LAUNCHER_SWITCH = 72
  
  #-----------------------------------------------------------------------------
  # The base number of Wonder Launcher points gained at the beginning of each turn.
  #-----------------------------------------------------------------------------
  WONDER_LAUNCHER_POINTS_PER_TURN = 1
  
  #-----------------------------------------------------------------------------
  # The maximum number of Wonder Launcher points a trainer may have at one time.
  #-----------------------------------------------------------------------------
  WONDER_LAUNCHER_MAX_POINTS = 14
  
  #-----------------------------------------------------------------------------
  # When true, the splash bars displaying each trainer's current LP totals will
  # be displayed at the start of each turn when their LP increases.
  #-----------------------------------------------------------------------------
  SHOW_LAUNCHER_SPLASH_EACH_TURN = true
end