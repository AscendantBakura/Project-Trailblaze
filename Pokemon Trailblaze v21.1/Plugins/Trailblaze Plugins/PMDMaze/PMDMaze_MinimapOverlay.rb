#===============================================================================
# PMDMaze - Minimap overlay (Trailblaze redesign)
#   * AUX2 toggles between the small corner map and the full centred map.
#   * Framed panel, explored floor tiles, wall outlines.
#   * Icon sheet "iconsOverlayTrailblaze" (7 slots): player, stairs down,
#     stairs up, item, NPC, trap, danger (F.O.E./hunter). Falls back to the
#     original 5-slot "iconsOverlayBig" sheet when the new sheet is missing.
#===============================================================================
$layoutStage = 0

module PMDMinimap
  ICON_SHEET      = "Graphics/UI/overlayUI/iconsOverlayTrailblaze"
  ICON_SLOTS      = 7
  SLOT_PLAYER     = 0
  SLOT_STAIRS     = 1
  SLOT_STAIRS_UP  = 2
  SLOT_ITEM       = 3
  SLOT_NPC        = 4
  SLOT_TRAP       = 5
  SLOT_DANGER     = 6
  LEGACY_SLOTS    = { 0 => 0, 1 => 1, 2 => 1, 3 => 2, 4 => 3, 5 => 4, 6 => 4 }
  PADDING         = 6
  FLOOR_COLOR     = Color.new(255, 255, 255, 70)
  WALL_COLOR      = Color.new(255, 182, 214, 150)
  PANEL_COLOR     = Color.new(20, 16, 32, 120)
  PANEL_BORDER    = Color.new(255, 182, 214, 200)

  module_function

  def tile_size
    return ($layoutStage == 0) ? 4 : 8
  end

  def icon_size
    return ($layoutStage == 0) ? PMDDungeon::DataStore.setting(:Config, :MINIMAP_ICON_SIZE_SMALL) : PMDDungeon::DataStore.setting(:Config, :MINIMAP_ICON_SIZE_FULL)
  end

  def layout_lines
    layout = $PokemonGlobal&.saveDungeonLayout
    return [] if !layout
    lines = layout.lines.map(&:chomp)
    width = lines.map(&:size).max || 0
    return lines.map { |l| l.ljust(width, "#") }
  end

  def canvas_size
    lines = layout_lines
    w = (lines.first ? lines.first.size : 0) * tile_size + (PADDING * 2)
    h = lines.size * tile_size + (PADDING * 2)
    return [[w, 1].max, [h, 1].max]
  end

  def icon_sheet
    @sheets ||= {}
    if pbResolveBitmap(ICON_SHEET)
      @sheets[:new] ||= Bitmap.new(ICON_SHEET)
      return [@sheets[:new], ICON_SLOTS, false]
    end
    @sheets[:legacy] ||= Bitmap.new(PMDDungeon::DataStore.setting(:Config, :MINIMAP_ICON_BIG))
    return [@sheets[:legacy], 5, true]
  end

  def draw_icon(bmp, slot, tile_x, tile_y)
    sheet, slots, legacy = icon_sheet
    slot = LEGACY_SLOTS[slot] if legacy
    raw_w = sheet.width / slots
    size = icon_size
    ts = tile_size
    dx = PADDING + (tile_x * ts) + ((ts - size) / 2)
    dy = PADDING + (tile_y * ts) + ((ts - size) / 2)
    bmp.stretch_blt(Rect.new(dx, dy, size, size), sheet, Rect.new(slot * raw_w, 0, raw_w, sheet.height))
  end

  def classify(event)
    name = event.name.to_s.downcase
    return SLOT_DANGER     if name.include?("_danger")
    return SLOT_STAIRS_UP  if name.include?("stairs_up")
    return nil             if name.include?("ladder_top")
    return SLOT_STAIRS     if name.include?("stairs")
    return SLOT_ITEM       if name.include?("_item_")
    return SLOT_TRAP       if name.include?("_trap_")
    return SLOT_NPC        if name.include?("_npc_") || name.include?("_copy")
    return nil
  end
end

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
  return PMDDungeon::DataStore.setting(:Config, :MAIN_DUNGEON_MAP_IDS).include?($game_map.map_id)
end

module Input
  class << self
    unless method_defined?(:layout_key_update)
      alias_method :layout_key_update, :update
    end

    def update
      layout_key_update
      if $game_temp && !$game_temp.in_battle && $scene.is_a?(Scene_Map) && minimap_enabled_for_current_map? && trigger?(Input::AUX2)
        $layoutStage = ($layoutStage == 0) ? 1 : 0
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

def minimap_finish_sprite(bmp, z)
  sprite = Sprite.new
  sprite.bitmap = bmp
  sprite.z = z
  anchor_x, anchor_y = minimap_anchor_position(sprite.bitmap)
  sprite.x = anchor_x
  sprite.y = anchor_y
  return sprite
end

def draw_saved_dungeon_from_string(dungeon_string, border_thickness = 2)
  lines = dungeon_string.lines.map(&:chomp)
  max_width = lines.map(&:size).max || 0
  lines.map! { |line| line.ljust(max_width, "#") }
  ts = PMDMinimap.tile_size
  pad = PMDMinimap::PADDING
  border_thickness = 1 if ts <= 4
  w, h = PMDMinimap.canvas_size
  bmp = Bitmap.new(w, h)
  visited = $PokemonGlobal&.dungeonVisitedTiles || {}
  if !visited.empty?
    bmp.fill_rect(0, 0, w, h, PMDMinimap::PANEL_COLOR)
    bmp.fill_rect(0, 0, w, 1, PMDMinimap::PANEL_BORDER)
    bmp.fill_rect(0, h - 1, w, 1, PMDMinimap::PANEL_BORDER)
    bmp.fill_rect(0, 0, 1, h, PMDMinimap::PANEL_BORDER)
    bmp.fill_rect(w - 1, 0, 1, h, PMDMinimap::PANEL_BORDER)
  end
  height = lines.size
  height.times do |y|
    max_width.times do |x|
      char = lines[y][x]
      px = pad + (x * ts)
      py = pad + (y * ts)
      if char != "#"
        bmp.fill_rect(px, py, ts, ts, PMDMinimap::FLOOR_COLOR) if visited["#{x},#{y}"]
        next
      end
      [[-1, 0], [1, 0], [0, -1], [0, 1]].each do |dx, dy|
        nx = x + dx
        ny = y + dy
        next if nx < 0 || ny < 0 || nx >= max_width || ny >= height
        next if lines[ny][nx] == "#" || !visited["#{nx},#{ny}"]
        case [dx, dy]
        when [-1, 0] then bmp.fill_rect(px, py, border_thickness, ts, PMDMinimap::WALL_COLOR)
        when [1, 0]  then bmp.fill_rect(px + ts - border_thickness, py, border_thickness, ts, PMDMinimap::WALL_COLOR)
        when [0, -1] then bmp.fill_rect(px, py, ts, border_thickness, PMDMinimap::WALL_COLOR)
        when [0, 1]  then bmp.fill_rect(px, py + ts - border_thickness, ts, border_thickness, PMDMinimap::WALL_COLOR)
        end
      end
    end
  end
  return minimap_finish_sprite(bmp, 50)
end

def create_events_dot_sprite(_tile_size = 8)
  w, h = PMDMinimap.canvas_size
  bmp = Bitmap.new(w, h)
  visited = $PokemonGlobal&.dungeonVisitedTiles || {}
  revealed_traps = $PokemonGlobal&.dungeonRevealedTraps || {}
  $game_map.events.each_value do |event|
    next if event.respond_to?(:erased?) && event.erased?
    slot = PMDMinimap.classify(event)
    next if slot.nil?
    stairs = [PMDMinimap::SLOT_STAIRS, PMDMinimap::SLOT_STAIRS_UP].include?(slot)
    if !stairs && slot != PMDMinimap::SLOT_DANGER
      hidden = false
      hidden ||= event.respond_to?(:transparent) && event.transparent
      hidden ||= event.respond_to?(:opacity) && event.opacity.to_i <= 0
      hidden ||= event.respond_to?(:character_name) && event.character_name.to_s.empty? && slot != PMDMinimap::SLOT_TRAP
      next if hidden
    end
    unless $DEBUG
      next if slot == PMDMinimap::SLOT_TRAP && !revealed_traps[event.id]
      next if slot == PMDMinimap::SLOT_STAIRS && !$PokemonGlobal.sawStairs
      next if slot == PMDMinimap::SLOT_STAIRS_UP && !visited["#{event.x},#{event.y}"]
      next if [PMDMinimap::SLOT_ITEM, PMDMinimap::SLOT_NPC].include?(slot) && !visited["#{event.x},#{event.y}"]
    end
    PMDMinimap.draw_icon(bmp, slot, event.x, event.y)
  end
  return minimap_finish_sprite(bmp, 51)
end

def create_player_dot_sprite
  w, h = PMDMinimap.canvas_size
  bmp = Bitmap.new(w, h)
  PMDMinimap.draw_icon(bmp, PMDMinimap::SLOT_PLAYER, $game_player.x, $game_player.y)
  return minimap_finish_sprite(bmp, 52)
end

def dispose_dungeon_minimap
  $game_temp.dungeon_layout_sprite&.dispose
  $game_temp.dungeon_layout_sprite = nil
  $game_temp.dungeon_player&.dispose
  $game_temp.dungeon_player = nil
  $game_temp.dungeon_events&.dispose
  $game_temp.dungeon_events = nil
end

EventHandlers.add(:on_map_or_spriteset_change, :show_dungeon_map,
  proc { |scene, _map_changed|
    next if !scene || !scene.spriteset
    dispose_dungeon_minimap
    next if !minimap_enabled_for_current_map? || !$PokemonGlobal.saveDungeonLayout
    PMDDungeon.reveal_around_player
    $PokemonGlobal.sawStairs = true if !$PokemonGlobal.sawStairs && stairsInRange?
    $game_temp.dungeon_layout_sprite = draw_saved_dungeon_from_string($PokemonGlobal.saveDungeonLayout)
    $game_temp.dungeon_player = create_player_dot_sprite
    $game_temp.dungeon_events = create_events_dot_sprite
    scene.spriteset.addUserSprite($game_temp.dungeon_layout_sprite)
    scene.spriteset.addUserSprite($game_temp.dungeon_player)
    scene.spriteset.addUserSprite($game_temp.dungeon_events)
  }
)

def stairsInRange?
  player_x = $game_player.x
  player_y = $game_player.y
  $game_map.events.each_value do |event|
    name = event.name.to_s
    next if !name.include?("stairs") || name.include?("stairs_up")
    return true if (event.x - player_x).abs <= 10 && (event.y - player_y).abs <= 7
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
    return if PMDMinimap.classify(self).nil?
    refreshEventsDungeonLayout
  end
end

EventHandlers.add(:on_player_step_taken, :change_dungeon_map,
  proc {
    next unless minimap_enabled_for_current_map?
    new_tiles = PMDDungeon.reveal_around_player
    if (!$game_temp.dungeon_layout_sprite && $PokemonGlobal.saveDungeonLayout) || new_tiles
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
  return if !$scene || !$scene.respond_to?(:spriteset) || !$scene.spriteset || !$PokemonGlobal.saveDungeonLayout
  $game_temp.dungeon_player&.dispose
  $game_temp.dungeon_player = create_player_dot_sprite
  $scene.spriteset.addUserSprite($game_temp.dungeon_player)
end

def refreshEventsDungeonLayout
  return if !$scene || !$scene.respond_to?(:spriteset) || !$scene.spriteset || !$PokemonGlobal.saveDungeonLayout
  $game_temp.dungeon_events&.dispose
  $game_temp.dungeon_events = create_events_dot_sprite
  $scene.spriteset.addUserSprite($game_temp.dungeon_events)
end

def rewriteDungeonLayoutAll
  return if !$scene || !$scene.respond_to?(:spriteset) || !$scene.spriteset || !$PokemonGlobal.saveDungeonLayout
  dispose_dungeon_minimap
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
