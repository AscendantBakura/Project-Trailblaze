$layoutStage = 0

def minimap_anchor_position(bitmap)
  margin = 12
  if $layoutStage == 1
    x = (Graphics.width - bitmap.width) / 2
    y = (Graphics.height - bitmap.height) / 2
    return x, y
  end

  x = [Graphics.width - bitmap.width - margin, margin].max
  y = margin
  return x, y
end

def minimap_enabled_for_current_map?
  return false if !$game_map
  return true if $game_map.metadata&.has_flag?("dungeonDisplay")
  return PMDDungeon::Config::MAIN_DUNGEON_MAP_IDS.include?($game_map.map_id)
end

module Input
  class << self
    unless method_defined?(:layout_key_update)
      alias_method :layout_key_update, :update
    end

    def update
      layout_key_update
      if $game_temp && !$game_temp.in_battle && $scene.is_a?(Scene_Map) && minimap_enabled_for_current_map? && trigger?(Input::AUX2)
        $layoutStage += 1
        $layoutStage = 0 if $layoutStage > 2
        rewriteDungeonLayoutAll
      end
    end
  end
end

class PokemonGlobalMetadata
    attr_accessor :saveDungeonLayout
    attr_accessor :saveLayoutCoordinates
    attr_accessor :sawStairs
  
    def saveDungeonLayout
        return @saveDungeonLayout || nil
    end

    def saveLayoutCoordinates
        return @saveLayoutCoordinates || nil
    end

    def sawStairs
      return @sawStairs || false
    end

end

def draw_saved_dungeon_from_string(dungeon_string, border_thickness = 2)
  lines = dungeon_string.lines.map(&:chomp)
  max_width = lines.map(&:size).max
  lines.map! { |line| line.ljust(max_width) }

  height = lines.size
  width  = max_width
  tile_size = ($layoutStage == 0) ? 4 : 8

  bmp_width = width * tile_size
  bmp_height = height * tile_size
  bmp = Bitmap.new(bmp_width, bmp_height)

  visited = $PokemonGlobal&.dungeonVisitedTiles || {}

  height.times do |y|
    width.times do |x|
      char = lines[y][x]
      next unless char

      px = x * tile_size
      py = y * tile_size

      if char != '#' && visited["#{x},#{y}"]
        bmp.fill_rect(px, py, tile_size, tile_size, Color.new(255, 255, 255, 56))
      end

      next unless char == '#'

      [[-1, 0], [1, 0], [0, -1], [0, 1]].each do |dx, dy|
        nx, ny = x + dx, y + dy
        next if nx < 0 || ny < 0 || nx >= width || ny >= height
        neighbor = lines[ny][nx]
        next if neighbor == '#'
        next unless visited["#{nx},#{ny}"]

        case [dx, dy]
        when [-1, 0]
          bmp.fill_rect(px, py, border_thickness, tile_size, Color.new(255, 255, 255, 56))
        when [1, 0]
          bmp.fill_rect(px + tile_size - border_thickness, py, border_thickness, tile_size, Color.new(255, 255, 255, 56))
        when [0, -1]
          bmp.fill_rect(px, py, tile_size, border_thickness, Color.new(255, 255, 255, 56))
        when [0, 1]
          bmp.fill_rect(px, py + tile_size - border_thickness, tile_size, border_thickness, Color.new(255, 255, 255, 56))
        end
      end

      [
        [-1, -1, px, py],
        [1, -1, px + tile_size - border_thickness, py],
        [-1, 1, px, py + tile_size - border_thickness],
        [1, 1, px + tile_size - border_thickness, py + tile_size - border_thickness]
      ].each do |dx, dy, ox, oy|
        nx, ny = x + dx, y + dy
        adj1 = [x + dx, y]
        adj2 = [x, y + dy]
        next if nx < 0 || ny < 0 || nx >= width || ny >= height
        next if lines[ny][nx] == '#' || lines[adj1[1]][adj1[0]] != '#' || lines[adj2[1]][adj2[0]] != '#'
        next unless visited["#{nx},#{ny}"]
        bmp.fill_rect(ox, oy, border_thickness, border_thickness, Color.new(255, 255, 255, 56))
      end
    end
  end

  sprite = Sprite.new
  sprite.bitmap = bmp
  sprite.bitmap.clear if $layoutStage == 2
  sprite.z = 50
  anchor_x, anchor_y = minimap_anchor_position(sprite.bitmap)
  sprite.x = anchor_x
  sprite.y = anchor_y
  return sprite
end

def create_events_dot_sprite(tile_size = 8)
  tile_size = ($layoutStage == 0) ? 4 : 8
  icon_size = ($layoutStage == 0) ? PMDDungeon::Config::MINIMAP_ICON_SIZE_SMALL : PMDDungeon::Config::MINIMAP_ICON_SIZE_FULL

  icon_bmp  = Bitmap.new(PMDDungeon::Config::MINIMAP_ICON_BIG)
  raw_icon_w = icon_bmp.width / 5

  width  = $PokemonGlobal.saveDungeonLayout.lines.first.chomp.size * tile_size
  height = $PokemonGlobal.saveDungeonLayout.lines.size * tile_size
  bmp = Bitmap.new(width, height)
  visited  = $PokemonGlobal&.dungeonVisitedTiles || {}
  revealed_traps = $PokemonGlobal&.dungeonRevealedTraps || {}

  $game_map.events.each_value do |event|
    next if event.respond_to?(:erased?) && event.erased?

    event_name = event.name.to_s.downcase
    is_stairs  = event_name.include?("stairs")
    is_item    = event_name.include?("_item_")
    is_npc     = event_name.include?("_npc_")
    is_trap    = event_name.include?("_trap_")
    is_event = event_name.include?("_copy") && !is_item && !is_npc && !is_stairs && !is_trap

    next unless is_stairs || is_item || is_npc || is_trap || is_event

    # Hide marker for events that have disappeared (item picked, NPC removed, trap consumed).
    if !is_stairs
      hidden = false
      hidden ||= event.respond_to?(:transparent) && event.transparent
      hidden ||= event.respond_to?(:opacity) && event.opacity.to_i <= 0
      hidden ||= event.respond_to?(:character_name) && event.character_name.to_s.empty?
      next if hidden
    end

    unless $DEBUG
      next if is_trap && !revealed_traps[event.id]
      next if is_stairs && !$PokemonGlobal.sawStairs
    end

    slot = if is_stairs  then 1
           elsif is_item then 2
           elsif is_npc  then 3
           elsif is_trap then 4
           else               3
           end

    src_x = slot * raw_icon_w
    src_rect = Rect.new(src_x, 0, raw_icon_w, icon_bmp.height)
    scaled_bmp = Bitmap.new(icon_size, icon_size)
    scaled_bmp.stretch_blt(Rect.new(0, 0, icon_size, icon_size), icon_bmp, src_rect)

    ev_x = event.x * tile_size
    ev_y = event.y * tile_size
    offset_x = (tile_size - icon_size) / 2
    offset_y = (tile_size - icon_size) / 2
    bmp.blt(ev_x + offset_x, ev_y + offset_y, scaled_bmp, Rect.new(0, 0, icon_size, icon_size))
    scaled_bmp.dispose
  end

  icon_bmp.dispose

  sprite = Sprite.new
  sprite.bitmap = bmp
  sprite.bitmap.clear if $layoutStage == 2
  sprite.z = 51
  anchor_x, anchor_y = minimap_anchor_position(sprite.bitmap)
  sprite.x = anchor_x
  sprite.y = anchor_y
  return sprite
end

def create_player_dot_sprite
  tile_size = ($layoutStage == 0) ? 4 : 8
  icon_size = ($layoutStage == 0) ? PMDDungeon::Config::MINIMAP_ICON_SIZE_SMALL : PMDDungeon::Config::MINIMAP_ICON_SIZE_FULL

  icon_bmp   = Bitmap.new(PMDDungeon::Config::MINIMAP_ICON_BIG)
  raw_icon_w = icon_bmp.width / 5

  width  = $PokemonGlobal.saveDungeonLayout.lines.first.chomp.size * tile_size
  height = $PokemonGlobal.saveDungeonLayout.lines.size * tile_size
  bmp = Bitmap.new(width, height)

  src_rect = Rect.new(0, 0, raw_icon_w, icon_bmp.height)
  scaled_bmp = Bitmap.new(icon_size, icon_size)
  scaled_bmp.stretch_blt(Rect.new(0, 0, icon_size, icon_size), icon_bmp, src_rect)

  px = $game_player.x * tile_size
  py = $game_player.y * tile_size
  offset_x = (tile_size - icon_size) / 2
  offset_y = (tile_size - icon_size) / 2
  bmp.blt(px + offset_x, py + offset_y, scaled_bmp, Rect.new(0, 0, icon_size, icon_size))

  scaled_bmp.dispose
  icon_bmp.dispose

  sprite = Sprite.new
  sprite.bitmap = bmp
  sprite.bitmap.clear if $layoutStage == 2
  sprite.z = 52
  anchor_x, anchor_y = minimap_anchor_position(sprite.bitmap)
  sprite.x = anchor_x
  sprite.y = anchor_y
  return sprite
end

EventHandlers.add(:on_map_or_spriteset_change, :show_dungeon_map,
  proc { |scene, _map_changed|
    next if !scene || !scene.spriteset
    if minimap_enabled_for_current_map?
      next if !$PokemonGlobal.saveDungeonLayout
      $PokemonGlobal.sawStairs = false
      $game_temp.dungeon_layout_sprite = draw_saved_dungeon_from_string($PokemonGlobal.saveDungeonLayout)
      $game_temp.dungeon_player = create_player_dot_sprite
      $game_temp.dungeon_events = create_events_dot_sprite
      scene.spriteset.addUserSprite($game_temp.dungeon_layout_sprite)
      scene.spriteset.addUserSprite($game_temp.dungeon_player)
      scene.spriteset.addUserSprite($game_temp.dungeon_events)
      if !$PokemonGlobal.sawStairs && stairsInRange?
        $PokemonGlobal.sawStairs = true
        refreshEventsDungeonLayout 
      end
    else
      $game_temp.dungeon_layout_sprite&.dispose
      $game_temp.dungeon_layout_sprite = nil
      $game_temp.dungeon_player&.dispose
      $game_temp.dungeon_player = nil
      $game_temp.dungeon_events&.dispose
      $game_temp.dungeon_events = nil
    end
  }
)

def stairsInRange?
  player_x = $game_player.x
  player_y = $game_player.y

  $game_map.events.each_value do |event|
    next if !event.name.include?("stairs")

    dx = (event.x - player_x).abs
    dy = (event.y - player_y).abs

    if dx <= 10 && dy <= 7
      return true
    end
  end

  return false
end

class Game_Event
  alias pmdmaze_event_marker_update update unless method_defined?(:pmdmaze_event_marker_update)

  def update
    old_x = @x
    old_y = @y
    pmdmaze_event_marker_update
    return if old_x == @x && old_y == @y
    return unless PMDDungeon.dungeon_map_active?

    event_name = @event&.name.to_s.downcase
    return if event_name.empty?
    is_trackable = event_name.include?("_item_") ||
                   event_name.include?("_npc_") ||
                   event_name.include?("_trap_") ||
                   event_name.include?("stairs") ||
                   event_name.include?("_copy")
    return unless is_trackable

    refreshEventsDungeonLayout
  end
end

EventHandlers.add(:on_player_step_taken, :change_dungeon_map,
  proc { 
    next unless minimap_enabled_for_current_map?
    new_tiles = PMDDungeon.reveal_around_player
    if !$game_temp.dungeon_layout_sprite && $PokemonGlobal.saveDungeonLayout
      rewriteDungeonLayoutAll
    elsif new_tiles
      rewriteDungeonLayoutAll
    else
      refresPlayerDungeonLayout
    end
    if !$PokemonGlobal.sawStairs && stairsInRange?
      $PokemonGlobal.sawStairs = true
      refreshEventsDungeonLayout 
    end
  }
)

def refresPlayerDungeonLayout
  return if !$scene || !$scene.spriteset || !$PokemonGlobal.saveDungeonLayout
  $game_temp.dungeon_player&.dispose
  $game_temp.dungeon_player = nil
  $game_temp.dungeon_player = create_player_dot_sprite
  $scene.spriteset.addUserSprite($game_temp.dungeon_player)
end

def refreshEventsDungeonLayout
  return if !$scene || !$scene.spriteset || !$PokemonGlobal.saveDungeonLayout
  $game_temp.dungeon_events&.dispose
  $game_temp.dungeon_events = nil
  $game_temp.dungeon_events = create_events_dot_sprite
  $scene.spriteset.addUserSprite($game_temp.dungeon_events)
end

def rewriteDungeonLayoutAll
  return if !$scene || !$scene.spriteset || !$PokemonGlobal.saveDungeonLayout
  $game_temp.dungeon_layout_sprite&.dispose
  $game_temp.dungeon_layout_sprite = nil
  $game_temp.dungeon_player&.dispose
  $game_temp.dungeon_player = nil
  $game_temp.dungeon_events&.dispose
  $game_temp.dungeon_events = nil

  PMDDungeon.reveal_around_player
  $game_temp.dungeon_layout_sprite = draw_saved_dungeon_from_string($PokemonGlobal.saveDungeonLayout)
  $game_temp.dungeon_player = create_player_dot_sprite
  $game_temp.dungeon_events = create_events_dot_sprite

  $scene.spriteset.addUserSprite($game_temp.dungeon_layout_sprite)
  $scene.spriteset.addUserSprite($game_temp.dungeon_player)
  $scene.spriteset.addUserSprite($game_temp.dungeon_events)
end

class Game_Temp
    attr_accessor :dungeon_layout_sprite
    attr_accessor :dungeon_player
    attr_accessor :dungeon_events
    attr_accessor :dungeon_trap_last_tile

    def dungeon_trap_last_tile
      @dungeon_trap_last_tile ||= {}
    end
end
