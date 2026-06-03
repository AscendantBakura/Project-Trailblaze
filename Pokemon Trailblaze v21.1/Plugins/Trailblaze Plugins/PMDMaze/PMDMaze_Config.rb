module PMDDungeon
  module Config
    #--------------------------------------------------------------------------
    # Map IDs
    #--------------------------------------------------------------------------
    # Event template source map containing at least event/item/trap template events.
    # Example:
    # EVENT_TEMPLATE_MAP_ID = 113
    EVENT_TEMPLATE_MAP_ID = 113
    TEMPLATE_EVENT_IDS = {
      event: 1,
      item: 2,
      trap: 4
    }

    # Dungeon runtime map IDs used by floor routing.
    # Example:
    # MAIN_DUNGEON_MAP_IDS = [108, 121]
    MAIN_DUNGEON_MAP_IDS = [108]

    # Floor routing example:
    # DUNGEON_MAP_BY_FLOOR = {
    #   (1..5)   => 108,
    #   (6..999) => 121
    # }
    DUNGEON_MAP_BY_FLOOR = {
      (1..999) => 108
    }

    #--------------------------------------------------------------------------
    # UI Assets
    #--------------------------------------------------------------------------
    FLOOR_CARD_BG_BY_TIME = {
      morning:   "Graphics/UI/Day-Transition.gif",
      afternoon: "Graphics/UI/Afternoon-Transition.gif",
      evening:   "Graphics/UI/Evening-Transition.gif",
      night:     "Graphics/UI/Night-Transition.gif"
    }
    FLOOR_CARD_DISPLAY_FRAMES = 60

    MINIMAP_ICON_BIG = "Graphics/UI/overlayUI/iconsOverlayBig"
    MINIMAP_ICON_SIZE_SMALL = 12
    MINIMAP_ICON_SIZE_FULL  = 18

    #--------------------------------------------------------------------------
    # Tileset Data
    #--------------------------------------------------------------------------
    # Override which DungeonTileset to use per dungeon map ID.
    # If a map ID isn't listed here, the map's own tileset_id is used instead.
    # Example:
    # DUNGEON_TILESET_DATA_ID_BY_MAP = {
    #   108 => :MINESHAFT,
    #   121 => :RUINS
    # }
    DUNGEON_TILESET_DATA_ID_BY_MAP = {}

    # Fallback DungeonTileset used when neither the map override nor the map's
    # own tileset_id resolves to a valid DungeonTileset entry.
    # Set to nil to disable the fallback.
    # Example: DEFAULT_DUNGEON_TILESET_DATA_ID = :DEFAULT
    DEFAULT_DUNGEON_TILESET_DATA_ID = nil

    #--------------------------------------------------------------------------
    # Variables / Switches
    #--------------------------------------------------------------------------
    # RMXP game variable ID to mirror the current dungeon floor number.
    # Set to nil to disable (floor won't be synced to any variable).
    # Example: DUNGEON_FLOOR_VARIABLE_ID = 5
    DUNGEON_FLOOR_VARIABLE_ID = nil

    # Name shown on the floor card per dungeon map ID.
    # Falls back to FLOOR_CARD_DEFAULT_TITLE if the map ID isn't listed.
    # Example:
    # DUNGEON_NAMES = {
    #   108 => "Deep Delve",
    #   121 => "Forgotten Ruins"
    # }
    DUNGEON_NAMES = {
      108 => "Mineshaft"
    }
    FLOOR_CARD_DEFAULT_TITLE = "Dungeon"
  end
end
