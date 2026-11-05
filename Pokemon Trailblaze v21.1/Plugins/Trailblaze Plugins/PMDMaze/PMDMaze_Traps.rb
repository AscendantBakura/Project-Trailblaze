class Game_Event
  alias pmdmaze_trap_refresh refresh
  def refresh
    pmdmaze_trap_refresh
    return unless $PokemonGlobal&.dungeonRevealedTraps
    graphic = $PokemonGlobal.dungeonRevealedTraps[@id]
    return unless graphic
    @character_name = graphic
    @transparent    = false
    @through        = true
  end
end

def pokemon_raised?(pkmn)
  return true if pkmn.hasType?(:FLYING)
  return true if pkmn.hasAbility?(:LEVITATE)
  return true if pkmn.item == :AIRBALLOON
  return false
end

def apply_trap_damage(target, damage, source_name)
  return if target.fainted?
  old_hp = target.hp
  target.hp = [target.hp - damage, 0].max
  dealt = old_hp - target.hp
  pbMessage(_INTL("{1} took {2} damage from the {3}!", target.name, dealt, source_name))
  if target.fainted?
    pbMessage(_INTL("{1} fainted!", target.name))
  end
end

def activateTrapEvent
  event = $game_map.events[@event_id]
  return if event.nil?
  name = event.name
  parts = name.split('_TRAP_')
  return if parts.size < 2
  # Trap events are named "..._TRAP_<rule id>", so look the rule up by id.
  trap_key = parts[1..-1].join('_TRAP_')
  rule = PMDDungeon::DataStore.setting(:TrapConfig, :TRAP_POOL).find { |r| r[:id].to_s == trap_key }
  rule ||= PMDDungeon::DataStore.setting(:TrapConfig, :TRAP_POOL)[trap_key.to_i] if trap_key[/\A\d+\z/]
  return if rule.nil?

  current_tile = "#{$game_player.x},#{$game_player.y}"
  $game_temp.dungeon_trap_last_tile ||= {}
  return if $game_temp.dungeon_trap_last_tile[@event_id] == current_tile
  $game_temp.dungeon_trap_last_tile[@event_id] = current_tile

  if rule[:graphic] && !rule[:graphic].empty?
    event.character_name = rule[:graphic]
    event.transparent    = false
    event.through        = true
    $PokemonGlobal.dungeonRevealedTraps[@event_id] = rule[:graphic]
    refreshEventsDungeonLayout
  end

  if rand < rule.fetch(:fail_chance, 0.05)
    pbMessage(_INTL("Luckily, it did not activate!"))
    return
  end

  activated = false
  case rule[:type]
  when :status
    executeDungeonStatusTrap(rule)
    activated = true
  when :explosion
    activated = executeDungeonExplosionTrap(rule)
  when :pp_down
    executeDungeonPPDownTrap(rule)
    activated = true
  when :spikes
    executeDungeonSpikesTrap(rule)
    activated = true
  when :teleport_room
    executeDungeonTeleportTrap(rule)
    activated = true
  when :floor_shift
    executeDungeonFloorShiftTrap(rule)
    activated = true
  when :miniboss
    executeDungeonMinibossTrap(rule)
    activated = true
  end

  if activated && rule[:disappears]
    $PokemonGlobal.dungeonRevealedTraps.delete(@event_id)
    event.character_name = ''
    event.transparent    = true
    event.erase
    $game_map.need_refresh = true if $game_map.respond_to?(:need_refresh=)
    refreshEventsDungeonLayout
  end
end

def executeDungeonStatusTrap(rule)
  status     = rule[:status]
  immunities = PMDDungeon::DataStore.setting(:TrapConfig, :STATUS_TYPE_IMMUNITIES)[status] || []

  eligible = $player.party.select do |pkmn|
    next false if pkmn.fainted?
    next false if pkmn.status != :NONE
    next false if immunities.any? { |type| pkmn.hasType?(type) }
    true
  end

  pbMessage(_INTL(rule[:message])) if rule[:message]

  if eligible.empty?
    pbMessage(_INTL("But it had no effect!"))
    return
  end

  target = eligible.sample
  target.status = status

  status_labels = {
    BURN: "burned", POISON: "poisoned", PARALYSIS: "paralyzed",
    SLEEP: "put to sleep", FROZEN: "frozen", FROSTBITE: "frostbitten"
  }
  label = status_labels[status] || status.to_s.downcase
  pbMessage(_INTL("{1} was {2}!", target.name, label))
end

def executeDungeonExplosionTrap(rule)
  pbMessage(_INTL(rule[:message])) if rule[:message]

  lead = $player.party.first
  if rule.fetch(:damp_blocked, true) && lead && !lead.fainted? && lead.hasAbility?(:DAMP)
    pbMessage(_INTL("{1}'s Damp prevented the explosion!", lead.name))
    return false
  end

  targets = $player.party.reject(&:fainted?)
  if targets.empty?
    return true
  end

  fainted_names = []
  targets.each do |pkmn|
    fraction = rule.fetch(:damage_fraction, 0.1)
    dmg = fraction == 0 ? 0 : [(pkmn.totalhp * fraction).ceil, 1].max
    old_hp = pkmn.hp
    pkmn.hp = [pkmn.hp - dmg, 0].max
    fainted_names << pkmn.name if old_hp > 0 && pkmn.fainted?
  end

  pbMessage(_INTL("The explosion damaged your whole party!"))
  if fainted_names.any?
    pbMessage(_INTL("Fainted: {1}", fainted_names.join(", ")))
  end
  return true
end

def executeDungeonPPDownTrap(rule)
  pbMessage(_INTL(rule[:message])) if rule[:message]

  eligible = $player.party.reject(&:fainted?)
  return if eligible.empty?

  target = eligible.sample
  moves_with_pp = target.moves.select { |m| m && m.total_pp > 0 && m.pp > 0 }
  if moves_with_pp.empty?
    pbMessage(_INTL("But {1} had no PP left to lose!", target.name))
    return
  end

  move = moves_with_pp.sample
  fraction = rule.fetch(:pp_fraction, 0.2)
  reduction = fraction == 0 ? 0 : [(move.total_pp * fraction).ceil, 1].max
  move.pp = [move.pp - reduction, 0].max
  pbMessage(_INTL("{1}'s {2} lost PP!", target.name, move.name))
end

def executeDungeonSpikesTrap(rule)
  pbMessage(_INTL(rule[:message])) if rule[:message]

  eligible = $player.party.reject { |pkmn| pkmn.fainted? || rule.fetch(:ignore_raised, true) && pokemon_raised?(pkmn) }
  if eligible.empty?
    pbMessage(_INTL("But the spikes couldn't reach!"))
    return
  end

  target = eligible.sample
  fraction = rule.fetch(:damage_fraction, 0.05)
  dmg = fraction == 0 ? 0 : [(target.totalhp * fraction).ceil, 1].max
  apply_trap_damage(target, dmg, "spikes")
end

def executeDungeonTeleportTrap(rule)
  pbMessage(_INTL(rule[:message])) if rule[:message]

  layout = $PokemonGlobal.saveDungeonLayout
  return if layout.nil?

  lines  = layout.lines.map(&:chomp)
  height = lines.size
  width  = lines.map(&:size).max
  lines.map! { |l| l.ljust(width) }

  room_tiles = []
  height.times do |y|
    width.times do |x|
      next if lines[y][x] == '#'
      open_neighbors = 0
      (-1..1).each do |dy|
        (-1..1).each do |dx|
          next if dx == 0 && dy == 0
          ny = y + dy
          nx = x + dx
          next if ny < 0 || nx < 0 || ny >= height || nx >= width
          open_neighbors += 1 if lines[ny][nx] != '#'
        end
      end
      room_tiles << [x, y] if open_neighbors >= 4
    end
  end

  return if room_tiles.empty?

  px = $game_player.x
  py = $game_player.y
  distance = rule.fetch(:teleport_distance, 5)
  candidates = room_tiles.reject { |tx, ty| (tx - px).abs < distance && (ty - py).abs < distance }
  candidates = room_tiles if candidates.empty?

  dest = candidates.sample
  $game_player.moveto(dest[0], dest[1])
  $game_map.refresh
  PMDDungeon.reveal_around_player
  rewriteDungeonLayoutAll
end

def executeDungeonFloorShiftTrap(rule)
  direction = rule[:direction] || :down
  current   = PMDDungeon.current_floor
  pbMessage(_INTL(rule[:message])) if rule[:message]

  if direction == :up
    return if current <= 1
    PMDDungeon.travel_to_floor(current - 1)
  else
    PMDDungeon.advance_to_next_floor
  end
end

def executeDungeonMinibossTrap(rule)
  pbMessage(_INTL(rule[:message])) if rule[:message]
  WildBattle.start(rule[:species], rule[:level] || 30)
end

EventHandlers.add(:on_player_step_taken, :pmdmaze_reset_trap_step_guard,
  proc {
    next if !$game_temp
    $game_temp.dungeon_trap_last_tile = {}
  }
)
