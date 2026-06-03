module PMDDungeon
  def self.floor_matches?(rule_floors, floor)
    case rule_floors
    when nil
      true
    when Integer
      rule_floors == floor
    when Range
      rule_floors.cover?(floor)
    when Array
      rule_floors.include?(floor)
    else
      false
    end
  end

  def self.rule_key(rule)
    return rule[:npc] if rule[:npc]
    return rule[:id] if rule[:id]
    return rule[:species] if rule[:species]
    return rule[:item] if rule[:item]
    return nil
  end

  def self.rule_allowed?(rule, floor, seen_counts, last_floors, floor_counts)
    key = rule_key(rule)
    return false if key.nil?
    return false if !floor_matches?(rule[:floors], floor)
    return false if rule[:unique_run] && seen_counts[key] > 0
    return false if rule[:max_total] && seen_counts[key] >= rule[:max_total]
    return false if rule[:max_per_floor] && floor_counts[key] >= rule[:max_per_floor]
    if rule[:min_floor_gap]
      last_floor = last_floors[key]
      return false if last_floor && (floor - last_floor) <= rule[:min_floor_gap]
    end
    return true
  end

  def self.pick_weighted_rule(rules, floor, seen_counts, last_floors, floor_counts, forced_key = nil)
    eligible = rules.select { |rule| rule_allowed?(rule, floor, seen_counts, last_floors, floor_counts) }
    return nil if eligible.empty?

    if forced_key
      forced_rule = eligible.find { |rule| rule_key(rule) == forced_key }
      return forced_rule if forced_rule
    end

    total_weight = eligible.sum { |rule| rule[:weight] || 1 }
    pick = rand * total_weight
    running = 0
    eligible.each do |rule|
      running += (rule[:weight] || 1)
      return rule if pick < running
    end
    return eligible.sample
  end

  def self.mark_rule_usage!(rule, floor, seen_counts, last_floors, floor_counts)
    key = rule_key(rule)
    return if key.nil?
    seen_counts[key] += 1
    floor_counts[key] += 1
    last_floors[key] = floor
  end

  def self.item_event_count_for_floor(floor)
    PMDDungeon::ItemConfig::ITEM_EVENT_COUNT_BY_FLOOR.fetch(floor, PMDDungeon::ItemConfig::DEFAULT_ITEM_EVENT_COUNT)
  end

  def self.pick_weighted_entry(entries)
    return nil if entries.nil? || entries.empty?
    total_weight = entries.sum { |entry| entry[1].to_f }
    return entries.sample if total_weight <= 0
    pick = rand * total_weight
    running = 0.0
    entries.each do |entry|
      running += entry[1].to_f
      return entry if pick < running
    end
    return entries.last
  end

  def self.item_rule_for_item(item_id)
    return PMDDungeon::ItemConfig::ITEM_POOL.find { |rule| rule[:item] == item_id }
  end

  def self.apply_item_graphic!(event, rule)
    rarity = (rule && rule[:rarity]) ? rule[:rarity] : :common
    gfx_map = PMDDungeon::ItemConfig::ITEM_RARITY_GRAPHIC || {}
    gfx = gfx_map[rarity] || gfx_map[:common] || {}

    event.pages[0].graphic.tile_id = 0
    event.pages[0].graphic.character_name = (gfx[:graphic] || 'trchar307').to_s
    # Keep template direction/pattern so chest closed/idle animation works as authored.
    event.pages[0].graphic.opacity = 255
    event.pages[0].graphic.blend_type = 0
  end

  def self.apply_item_open_frame!(event, item_symbol)
    rule = item_rule_for_item(item_symbol)
    rarity = (rule && rule[:rarity]) ? rule[:rarity] : :common
    gfx_map = PMDDungeon::ItemConfig::ITEM_RARITY_GRAPHIC || {}
    gfx = gfx_map[rarity] || gfx_map[:common] || {}
    return if !gfx

    # Optional: set explicit open frame before reward popup.
    event.direction = (gfx[:open_direction] || event.direction).to_i if event.respond_to?(:direction=)
    event.pattern = (gfx[:open_pattern] || event.pattern).to_i if event.respond_to?(:pattern=)
    event.refresh if event.respond_to?(:refresh)
  end

  def self.clone_template_event(new_map, current_map, template_id)
    template_event = new_map.events[template_id]
    return nil if template_event.nil?

    new_event = Marshal.load(Marshal.dump(template_event))
    new_id = current_map.events.keys.max.to_i + 1
    new_event.instance_variable_set(:@id, new_id)
    return [new_event, new_id]
  end

  def self.npc_rule_for_key(npc_key)
    return PMDDungeon::EventConfig::NPC_POOL.find { |r| r[:npc] == npc_key }
  end

  def self.npc_key_from_event_name(event_name)
    npc_part = event_name.to_s.split('_NPC_').last.to_s
    token = npc_part.split('_').first
    return nil if !token || token.empty?
    return token.to_sym
  end

  def self.required_item_from_event_name(event_name)
    npc_part = event_name.to_s.split('_NPC_').last.to_s
    parts = npc_part.split('_')
    return nil if parts.length < 2
    token = parts[1]
    return nil if !token || token.empty? || token == 'NONE'
    return token.to_sym
  end

  def self.resolve_required_item(rule)
    required_item = rule[:required_item]
    return nil if required_item.nil?
    if required_item == :random
      pool = PMDDungeon::EventConfig::NPC_ITEM_POOL || []
      return pool.sample if pool.any?
      return nil
    end
    return required_item
  end

  def self.random_bribe_item
    pool = PMDDungeon::ItemConfig::ITEM_POOL.map { |rule| rule[:item] }.compact
    pool = PMDDungeon::EventConfig::NPC_ITEM_POOL if pool.empty?
    pool = [:POTION] if pool.empty?
    return pool.sample
  end

  def self.closest_room_center_tile(origin_x, origin_y)
    layout = $PokemonGlobal&.saveDungeonLayout
    return nil if !layout
    lines = layout.lines.map(&:chomp)
    return nil if lines.empty?

    best = nil
    best_score = -1
    best_dist = 1_000_000

    lines.each_with_index do |line, y|
      line.chars.each_with_index do |ch, x|
        next if ch == '#'

        score = 0
        [[1, 0], [-1, 0], [0, 1], [0, -1]].each do |dx, dy|
          (1..2).each do |step|
            nx = x + (dx * step)
            ny = y + (dy * step)
            break if ny < 0 || ny >= lines.length
            row = lines[ny]
            break if nx < 0 || nx >= row.length
            break if row[nx] == '#'
            score += 1
          end
        end

        dist = (origin_x - x).abs + (origin_y - y).abs
        if score > best_score || (score == best_score && dist < best_dist)
          best = [x, y]
          best_score = score
          best_dist = dist
        end
      end
    end

    return best
  end

  def self.outlaw_active?(event)
    return false if !event || event.name.to_s.empty?
    return false if !event.name.include?('_NPC_')
    npc_key = npc_key_from_event_name(event.name)
    return false if npc_key.nil?
    rule = npc_rule_for_key(npc_key)
    return false if rule.nil? || rule[:type] != :outlaw

    state_data = $PokemonGlobal.dungeonNpcQuestState[npc_key]
    state = state_data.is_a?(Hash) ? state_data[:state] : state_data
    return false if state == :completed || state == :released
    return true
  end

  def self.reset_floor_event_state(floor)
    # Reset non-unique event spawn counters when leaving a floor.
    state_map = $PokemonGlobal.dungeonNpcQuestState || {}
    PMDDungeon::EventConfig::NPC_POOL.each do |rule|
      next if rule[:unique_run]
      npc_key = rule[:npc]
      state_data = state_map[npc_key]
      state = state_data.is_a?(Hash) ? state_data[:state] : state_data
      state_map.delete(npc_key) unless state == :completed
    end
  end
end

class Game_Event
  alias pmdmaze_event_ai_update update unless method_defined?(:pmdmaze_event_ai_update)

  def update
    pmdmaze_event_ai_update
    return if !$game_map || !$PokemonGlobal
    return if !PMDDungeon.dungeon_map_active?
    return if !PMDDungeon.outlaw_active?(self)
    return if moving? || jumping?
    return if defined?(@locked) && @locked
    return if rand(100) >= 65
    move_away_from_player
  end
end

def createDungeonEvents(_complexity, current_map, new_map_id = PMDDungeon::Config::EVENT_TEMPLATE_MAP_ID)
  return if $player.able_pokemon_count == 0

  floor = PMDDungeon.current_floor
  new_map = load_data(sprintf('Data/Map%03d.rxdata', new_map_id))
  template_ids = PMDDungeon::Config::TEMPLATE_EVENT_IDS

  item_seen = $PokemonGlobal.dungeonSpawnedItems
  npc_seen = $PokemonGlobal.dungeonSpawnedNpcs
  trap_seen = $PokemonGlobal.dungeonSpawnedTraps
  npc_state = $PokemonGlobal.dungeonNpcQuestState
  item_last_floor = $PokemonGlobal.dungeonLastItemFloor
  trap_last_floor = $PokemonGlobal.dungeonLastTrapFloor
  npc_last_floor = {}
  item_floor_counts = Hash.new(0)
  npc_floor_counts = Hash.new(0)
  trap_floor_counts = Hash.new(0)

  event_template_id = template_ids[:event]
  forced_items = []

  dungeon_map_id = ($game_map && $game_map.map_id) || PMDDungeon.map_id_for_floor(floor)
  max_events = PMDDungeon.max_events_for_floor(floor, dungeon_map_id)
  spawned_count = 0

  # Build eligible event lists.
  eligible_npcs = PMDDungeon::EventConfig::NPC_POOL.select do |rule|
    next false unless PMDDungeon.floor_matches?(rule[:floors], floor)
    npc_key = rule[:npc]
    next false if rule[:unique_run] && npc_seen[npc_key] > 0
    state_data = npc_state[npc_key]
    state = state_data.is_a?(Hash) ? state_data[:state] : state_data
    next false if state == :completed
    true
  end

  eligible_items = PMDDungeon::ItemConfig::ITEM_POOL.select do |rule|
    next false unless PMDDungeon.floor_matches?(rule[:floors], floor)
    key = rule[:item]
    next false if rule[:unique_run] && item_seen[key] > 0
    true
  end

  eligible_traps = PMDDungeon::TrapConfig::TRAP_POOL.select do |rule|
    next false unless PMDDungeon.floor_matches?(rule[:floors], floor)
    true
  end

  item_chance = PMDDungeon::EventConfig::ITEM_SPAWN_CHANCE
  npc_chance  = PMDDungeon::EventConfig::NPC_SPAWN_CHANCE
  trap_chance = PMDDungeon::EventConfig::TRAP_SPAWN_CHANCE

  # Spawn events up to max_events by picking available types repeatedly.
  attempts = 0
  max_attempts = [max_events * 8, 16].max
  while spawned_count < max_events && attempts < max_attempts
    attempts += 1

    eligible_items = eligible_items.select do |rule|
      PMDDungeon.rule_allowed?(rule, floor, item_seen, item_last_floor, item_floor_counts)
    end
    eligible_npcs = eligible_npcs.select do |rule|
      npc_key = rule[:npc]
      state_data = npc_state[npc_key]
      state = state_data.is_a?(Hash) ? state_data[:state] : state_data
      PMDDungeon.floor_matches?(rule[:floors], floor) &&
        state != :completed &&
        PMDDungeon.rule_allowed?(rule, floor, npc_seen, npc_last_floor, npc_floor_counts)
    end
    eligible_traps = eligible_traps.select do |rule|
      PMDDungeon.rule_allowed?(rule, floor, trap_seen, trap_last_floor, trap_floor_counts)
    end

    type_weights = []
    type_weights << [:item, item_chance] if item_chance.to_f > 0 && eligible_items.any?
    type_weights << [:npc, npc_chance] if npc_chance.to_f > 0 && eligible_npcs.any?
    type_weights << [:trap, trap_chance] if trap_chance.to_f > 0 && eligible_traps.any?
    break if type_weights.empty?

    selected = PMDDungeon.pick_weighted_entry(type_weights)
    next if selected.nil?

    case selected[0]
    when :item
      rule = PMDDungeon.pick_weighted_rule(
        eligible_items,
        floor,
        item_seen,
        item_last_floor,
        item_floor_counts
      )
      next if rule.nil?

      event_pair = PMDDungeon.clone_template_event(new_map, current_map, template_ids[:item])
      next if event_pair.nil?
      new_event, new_id = event_pair
      item_id = rule[:item]
      new_event.name += "_copy#{new_id}_ITEM_#{item_id}"
      PMDDungeon.apply_item_graphic!(new_event, rule)
      current_map.events[new_id] = new_event
      PMDDungeon.mark_rule_usage!(rule, floor, item_seen, item_last_floor, item_floor_counts)
      spawned_count += 1

    when :npc
      rule = PMDDungeon.pick_weighted_rule(
        eligible_npcs,
        floor,
        npc_seen,
        npc_last_floor,
        npc_floor_counts
      )
      next if rule.nil?
      next if rand >= (rule[:spawn_chance] || 1.0)

      event_pair = PMDDungeon.clone_template_event(new_map, current_map, event_template_id)
      next if event_pair.nil?
      new_event, new_id = event_pair

      npc_key = rule[:npc]
      required_item = PMDDungeon.resolve_required_item(rule)
      item_tag = required_item ? required_item.to_s : 'NONE'

      new_event.name += "_copy#{new_id}_NPC_#{npc_key}_#{item_tag}"
      new_event.pages[0].graphic.tile_id = 0
      new_event.pages[0].graphic.character_name = rule[:graphic].to_s
      new_event.pages[0].graphic.direction = 2
      new_event.pages[0].graphic.pattern = 0
      new_event.pages[0].graphic.opacity = 255
      new_event.pages[0].graphic.blend_type = 0
      current_map.events[new_id] = new_event
      PMDDungeon.mark_rule_usage!(rule, floor, npc_seen, npc_last_floor, npc_floor_counts)
      forced_items << required_item if required_item
      spawned_count += 1

    else
      rule = PMDDungeon.pick_weighted_rule(
        eligible_traps,
        floor,
        trap_seen,
        trap_last_floor,
        trap_floor_counts
      )
      next if rule.nil?

      event_pair = PMDDungeon.clone_template_event(new_map, current_map, template_ids[:trap])
      next if event_pair.nil?
      new_event, new_id = event_pair
      trap_id = rule[:id]
      new_event.name += "_copy#{new_id}_TRAP_#{trap_id}"
      new_event.pages[0].graphic.tile_id = 0
      new_event.pages[0].graphic.character_name = ''
      current_map.events[new_id] = new_event
      PMDDungeon.mark_rule_usage!(rule, floor, trap_seen, trap_last_floor, trap_floor_counts)
      spawned_count += 1
    end
  end

  # Spawn forced items associated with quest NPCs.
  forced_items.uniq.each do |item_id|
    event_pair = PMDDungeon.clone_template_event(new_map, current_map, template_ids[:item])
    next if event_pair.nil?
    new_event, new_id = event_pair
    new_event.name += "_copy#{new_id}_ITEM_#{item_id}"
    PMDDungeon.apply_item_graphic!(new_event, PMDDungeon.item_rule_for_item(item_id))
    current_map.events[new_id] = new_event
  end
end

# Compatibility shim for older calls.
def createPokemonEventsDungeon(complexity, current_map, new_map_id = PMDDungeon::Config::EVENT_TEMPLATE_MAP_ID)
  createDungeonEvents(complexity, current_map, new_map_id)
end

def getItemDungeonEvent
  name = $game_map.events[@event_id].name
  item_part = name.split('_ITEM_').last.to_s
  item_symbol = item_part.split('_').first.to_sym
  event = $game_map.events[@event_id]
  PMDDungeon.apply_item_open_frame!(event, item_symbol) if event
  item = GameData::Item.get(item_symbol)
  quantity = item.is_poke_ball? ? rand(2) + 1 : 1
  pbItemBall(item, quantity)
  $game_map.events[@event_id].character_name = ''
  refreshEventsDungeonLayout
end

def dialogueEvent
  name = $game_map.events[@event_id].name
  return false if !name.include?('_NPC_')
  return npcQuestEvent
end

# Compatibility shim for existing event commands.
def dialoguePokeEvent
  return dialogueEvent
end

def npcQuestEvent
  event = $game_map.events[@event_id]
  return false if event.nil?

  npc_key = PMDDungeon.npc_key_from_event_name(event.name)
  return false if npc_key.nil?

  rule = PMDDungeon.npc_rule_for_key(npc_key)
  return false if rule.nil?

  case rule[:type]
  when :outlaw
    return handleOutlawNpcEvent(event, npc_key, rule)
  when :nurse
    return handleNurseNpcEvent(event, npc_key, rule)
  else
    return handleGenericNpcQuestEvent(event, npc_key, rule)
  end
end

def handleGenericNpcQuestEvent(event, npc_key, rule)
  state_map = $PokemonGlobal.dungeonNpcQuestState
  state = state_map[npc_key] || :new
  state = state[:state] if state.is_a?(Hash)
  return true if state == :completed

  required_item = PMDDungeon.required_item_from_event_name(event.name)
  has_item = required_item && $bag.has?(required_item)

  if state == :new
    pbMessage(_INTL(rule[:dialogue_no_item])) if rule[:dialogue_no_item]
    state_map[npc_key] = { state: :asked }
    return true if !has_item
  end

  pbMessage(_INTL(rule[:dialogue_no_item])) if state == :asked && rule[:dialogue_no_item]
  return true if !has_item

  item_name = GameData::Item.get(required_item).name
  return true if !pbConfirmMessage(_INTL('Give {1}?', item_name))

  pbMessage(_INTL(rule[:dialogue_have_item])) if rule[:dialogue_have_item]
  $bag.remove(required_item, 1)
  pbMessage(_INTL(rule[:dialogue_reward])) if rule[:dialogue_reward]
  pbReceiveItem(rule[:reward_item]) if rule[:reward_item]
  state_map[npc_key] = { state: :completed }
  removeNpcQuestEventWithEffect(event.id)
  return true
end

def handleOutlawNpcEvent(event, npc_key, rule)
  state_map = $PokemonGlobal.dungeonNpcQuestState
  state_data = state_map[npc_key]
  state = state_data.is_a?(Hash) ? state_data[:state] : state_data
  state ||= :new

  if state == :released
    pbMessage(_INTL(rule[:dialogue_repeat] || 'I already paid you. Keep moving.'))
    return true
  end

  return true if state == :completed

  pbMessage(_INTL(rule[:dialogue_caught] || 'Do not turn me in!'))

  bribe_item = PMDDungeon.random_bribe_item
  bribe_name = GameData::Item.get(bribe_item).name

  take_bribe = pbConfirmMessage(_INTL('Accept {1} and let them go?', bribe_name))

  if !take_bribe
    pbMessage(_INTL(rule[:dialogue_turned_in] || 'Things were a lot simpler when I was robbing banks with the Deadlock Gang'))
    state_map[npc_key] = { state: :completed }
    removeNpcQuestEventWithEffect(event.id)
    return true
  end

  pbReceiveItem(bribe_item)
  target_tile = PMDDungeon.closest_room_center_tile(event.x, event.y)
  if target_tile
    event.moveto(target_tile[0], target_tile[1])
  end
  state_map[npc_key] = { state: :released, bribe_item: bribe_item }
  pbMessage(_INTL(rule[:dialogue_after_bribe] || 'You did not see me.'))
  refreshEventsDungeonLayout
  return true
end

def handleNurseNpcEvent(event, npc_key, rule)
  state_map = $PokemonGlobal.dungeonNpcQuestState
  state_data = state_map[npc_key]
  state = state_data.is_a?(Hash) ? state_data[:state] : state_data
  return true if state == :completed

  pbMessage(_INTL(rule[:dialogue_before] || 'Let me heal your team.'))

  $player.party.each { |pkmn| pkmn.heal if pkmn }

  pbMessage(_INTL(rule[:dialogue_after] || 'You are all set.'))

  state_map[npc_key] = { state: :completed }
  removeNpcQuestEventWithEffect(event.id)
  return true
end

def removeNpcQuestEventWithEffect(event_id)
  event = $game_map.events[event_id]
  return if event.nil?

  overlay = Sprite.new
  overlay.bitmap = Bitmap.new(Graphics.width, Graphics.height)
  overlay.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
  overlay.opacity = 0
  overlay.z = 99_999

  16.times do
    overlay.opacity += 16
    Graphics.update
  end

  pbWait(0.35)

  begin
    pbSEPlay('Exit Door')
  rescue StandardError
  end

  event.character_name = ''
  event.transparent = true
  event.opacity = 0
  event.erase if event.respond_to?(:erase)
  refreshEventsDungeonLayout

  pbWait(0.2)

  16.times do
    overlay.opacity -= 16
    Graphics.update
  end

  overlay.dispose
end
