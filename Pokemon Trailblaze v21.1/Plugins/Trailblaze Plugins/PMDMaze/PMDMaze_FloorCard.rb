class NextFloor
  def initialize
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    setup
  end

  def floor_card_bg_path
    bgs = PMDDungeon::Config::FLOOR_CARD_BG_BY_TIME
    return bgs[:day] if !$game_switches || !defined?(TrailblazeTimeHUD)
    return bgs[:morning]   if $game_switches[TrailblazeTimeHUD::TIME_SWITCHES["MORNING"]]
    return bgs[:afternoon] if $game_switches[TrailblazeTimeHUD::TIME_SWITCHES["AFTERNOON"]]
    return bgs[:evening]   if $game_switches[TrailblazeTimeHUD::TIME_SWITCHES["EVENING"]]
    return bgs[:night]     if $game_switches[TrailblazeTimeHUD::TIME_SWITCHES["NIGHT"]]
    return bgs[:day]
  end

  def setup
    @sprites["bg"] = IconSprite.new(0, 0, @viewport)
    @sprites["bg"].setBitmap(floor_card_bg_path)
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["overlay"].bitmap.font.name = "Cafeteria Black"
    @sprites["overlay"].bitmap.font.size = 60
    base_color   = Color.new(255, 255, 255, 255)
    shadow_color = Color.new(0, 0, 0, 255)
    dungeon_map_id = PMDDungeon.map_id_for_floor($PokemonGlobal.dungeonFloor)
    dungeon_title = PMDDungeon::Config::DUNGEON_NAMES[dungeon_map_id] || PMDDungeon::Config::FLOOR_CARD_DEFAULT_TITLE
    text = "<ac>" + _INTL("{1}\n\nFloor {2}", dungeon_title, $PokemonGlobal.dungeonFloor) + "</ac>"
    drawFormattedTextEx(@sprites["overlay"].bitmap, 0, Graphics.height / 2 - 80, @sprites["overlay"].bitmap.width, text, base_color, shadow_color)

    pbFadeInAndShow(@sprites)
    PMDDungeon::Config::FLOOR_CARD_DISPLAY_FRAMES.times do
      pbUpdateSpriteHash(@sprites)
      Graphics.update
      Input.update
    end

    dispose
  end

  def dispose
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end
