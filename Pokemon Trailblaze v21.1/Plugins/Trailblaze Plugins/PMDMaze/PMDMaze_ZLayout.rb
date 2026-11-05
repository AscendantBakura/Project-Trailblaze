#===============================================================================
# PMDMaze - Floor layout guarantees and path finding (Trailblaze restoration)
#   * Clears stale room rects between generator redraws and records the rooms
#     of the generated floor.
#   * Floor patches (grass) are generated less often (GRASS_PATCH_FACTOR).
#   * secure_floor! guarantees that every room, both stairs and every
#     interactive event can be reached from the arrival without walking through
#     blocking events or traps, and keeps the stairs' neighbours clear.
#   * Bounty rooms: a room with a single entrance (extra entrances are sealed
#     with boulders when that keeps the floor connected) and no traps.
#   * Breadth-first path finding for chasers (F.O.E./hunter) and cross-floor
#     routes through the connecting stairs.
#===============================================================================
module PMDDungeon
  module Layout
    DIRS = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    NEIGH4 = [[1, 0], [-1, 0], [0, 1], [0, -1]]
    NEIGH8 = [[-1, -1], [0, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [0, 1], [1, 1]]
    SEAL_NAME = "_rock_seal"

    class << self
      attr_accessor :last_rects, :last_size, :floor_reserved, :last_report, :last_decor
    end

    module_function

    def cfg
      return PMDDungeon::FeatureConfig
    end

    #---------------------------------------------------------------------------
    # Generator capture
    #---------------------------------------------------------------------------
    def reset_capture
      self.last_rects = nil
      self.last_size = nil
      self.floor_reserved = []
      self.last_decor = {}
    end

    def capture(dungeon)
      rects = dungeon.instance_variable_get(:@room_rects) || []
      self.last_rects = rects.map { |r| r.dup }
      self.last_size = [dungeon.width, dungeon.height]
      self.last_decor = capture_decor(dungeon)
    end

    # Floor decorations (e.g. tree trunks) look like plain floor in the layout
    # text, so their tiles are recorded here: tile => top-left of its footprint.
    def capture_decor(dungeon)
      data = dungeon.instance_variable_get(:@map_data)
      decor = {}
      return decor if !data || !dungeon.width || !dungeon.height
      dungeon.width.times do |x|
        dungeon.height.times do |y|
          case data[x, y, 0]
          when :floor_decoration_large
            [[0, 0], [1, 0], [0, 1], [1, 1]].each { |dx, dy| decor[[x + dx, y + dy]] = [x, y, 2] }
          when :floor_decoration
            decor[[x, y]] = [x, y, 1]
          end
        end
      end
      return decor
    end

    def decor_tile?(x, y)
      return (last_decor || {}).key?([x, y])
    end

    def stairs_tile_ok?(map, walk, occ, others, x, y, ladder)
      return false if decor_tile?(x, y) || occ[[x, y]] || !walk.call(x, y)
      return false if ladder && (y < 1 || decor_tile?(x, y - 1) || occ[[x, y - 1]])
      return false if NEIGH4.any? { |dx, dy| !walk.call(x + dx, y + dy) }
      return false if others.any? { |o| (o[0] - x).abs <= 2 && (o[1] - y).abs <= 2 }
      return true
    end

    # Stairs must never sit on a decoration: move them to the nearest plain,
    # reachable tile (the ladder top follows the up stairs). If none exists,
    # the decoration under them is cleared instead.
    def clear_stairs_decor!(map, layout, sx, sy, report)
      return if (last_decor || {}).empty?
      stairs_events(map).each do |st|
        next if !decor_tile?(st.x, st.y)
        up = ev_name(st)[/\Astairs_up\z/i] ? true : false
        ladder = up ? map.events.values.find { |e| ev_name(e)[/\Aladder_top\z/i] && e.x == st.x && e.y == st.y - 1 } : nil
        walk = SeededFloors.walkable_proc(map, layout)
        blocked, traps = event_index(map)
        reach = flood([sx, sy], map.width, map.height, proc { |x, y| walk.call(x, y) && !blocked[[x, y]] && !traps[[x, y]] })
        occ = {}
        map.events.each_value { |e| occ[[e.x, e.y]] = true if !e.equal?(st) && !e.equal?(ladder) && e.x >= 0 }
        others = stairs_events(map).reject { |o| o.equal?(st) }.map { |o| [o.x, o.y] }
        dest = reach.keys.select { |x, y| stairs_tile_ok?(map, walk, occ, others, x, y, ladder) }
                    .min_by { |x, y| [(x - st.x).abs + (y - st.y).abs, y, x] }
        if dest
          report[:moved] << [st.id, ev_name(st), [st.x, st.y], dest] if report
          st.x, st.y = dest
          ladder.x, ladder.y = dest[0], dest[1] - 1 if ladder
        else
          ox, oy, size = last_decor[[st.x, st.y]]
          floor_tile = map.data[sx, sy, 0]
          size.times { |dx| size.times { |dy| clear_decor_tile!(map, ox + dx, oy + dy, floor_tile) } }
          report[:carved] = report[:carved].to_i + size * size if report
        end
      end
    end

    def clear_decor_tile!(map, x, y, floor_tile)
      return if x < 0 || y < 0 || x >= map.width || y >= map.height
      map.data[x, y, 0] = floor_tile
      map.data[x, y, 1] = 0
      map.data[x, y, 2] = 0
      last_decor.delete([x, y])
    end

    def scaled_patch_chance(chance)
      factor = cfg.const_defined?(:GRASS_PATCH_FACTOR) ? PMDDungeon::DataStore.setting(:FeatureConfig, :GRASS_PATCH_FACTOR) : 1.0
      return (chance.to_f * factor).round.clamp(0, 100)
    end

    #---------------------------------------------------------------------------
    # Event classification (works for RPG::Event and Game_Event)
    #---------------------------------------------------------------------------
    def ev_name(ev)
      return ev.name.to_s
    end

    def first_page(ev)
      return ev.respond_to?(:pages) && ev.pages ? ev.pages[0] : nil
    end

    def stairs?(ev)
      n = ev_name(ev)
      return false if n[/ladder_top/i]
      return n[/stairs/i] ? true : false
    end

    def seal?(ev)
      return ev_name(ev) == SEAL_NAME
    end

    def decorative?(ev)
      return ev_name(ev)[/ladder_top|time of day/i] ? true : false
    end

    def trap?(ev)
      return ev_name(ev)[/_trap_/i] ? true : false
    end

    def trainer?(ev)
      return ev_name(ev)[/\ATrainer\(\d+\)/i] ? true : false
    end

    def interactive?(ev)
      return false if stairs?(ev) || trap?(ev) || seal?(ev) || decorative?(ev)
      return ev_name(ev)[/_item_|_npc|Trainer\(|_bounty|SMUGGLER|CRIMINAL/i] ? true : false
    end

    def tile_event_blocks?(map, tile_id)
      tileset = $data_tilesets && $data_tilesets[map.tileset_id]
      return false if !tileset
      passage = tileset.passages[tile_id] || 0
      return (passage & 0x0f) == 0x0f
    end

    def blocking?(map, ev)
      page = first_page(ev)
      return false if !page || page.through
      return true if page.graphic.character_name.to_s != ""
      return page.graphic.tile_id > 0 && tile_event_blocks?(map, page.graphic.tile_id)
    end

    def obstacle?(map, ev)
      return false if stairs?(ev) || decorative?(ev)
      return trap?(ev) || blocking?(map, ev)
    end

    def stairs_events(map)
      return map.events.values.select { |ev| stairs?(ev) && ev.x >= 0 }.sort_by(&:id)
    end

    #---------------------------------------------------------------------------
    # Grid helpers
    #---------------------------------------------------------------------------
    # Breadth-first flood; the start tile is always included.
    def flood(start, width, height, passable)
      seen = { start => nil }
      queue = [start]
      until queue.empty?
        cur = queue.shift
        NEIGH4.each do |dx, dy|
          nx = cur[0] + dx
          ny = cur[1] + dy
          next if nx < 0 || ny < 0 || nx >= width || ny >= height
          nxt = [nx, ny]
          next if seen.has_key?(nxt) || !passable.call(nx, ny)
          seen[nxt] = cur
          queue << nxt
        end
      end
      return seen
    end

    def trace(parents, tile)
      path = []
      while tile
        path.unshift(tile)
        tile = parents[tile]
      end
      return path
    end

    def touchable?(reach, x, y)
      return true if reach.has_key?([x, y])
      return NEIGH4.any? { |dx, dy| reach.has_key?([x + dx, y + dy]) }
    end

    def layout_walk(lines)
      return proc { |x, y|
        row = (y >= 0) ? lines[y] : nil
        next false if !row || x < 0 || row[x].nil?
        row[x] != "#"
      }
    end

    def grass_tile?(map, x, y)
      ranges = PMDDungeon::DataStore.setting(:FeatureConfig, :HIDING_TILE_RANGES)[map.tileset_id] || []
      tileset = $data_tilesets && $data_tilesets[map.tileset_id]
      tags = tileset.respond_to?(:terrain_tags) ? tileset.terrain_tags : nil
      [0, 1, 2].each do |z|
        tile = map.data[x, y, z]
        next if !tile || tile == 0
        return true if ranges.any? { |r| r.include?(tile) }
        return true if tags && PMDDungeon::DataStore.setting(:FeatureConfig, :HIDING_TERRAIN_TAGS).include?(tags[tile].to_i)
      end
      return false
    end

    #---------------------------------------------------------------------------
    # Rooms
    #---------------------------------------------------------------------------
    def rect_tiles(rect)
      x, y, w, h = rect
      tiles = []
      (y...(y + h)).each { |j| (x...(x + w)).each { |i| tiles << [i, j] } }
      return tiles
    end

    def in_rect?(rect, x, y, margin = 0)
      return x >= rect[0] - margin && y >= rect[1] - margin &&
             x < rect[0] + rect[2] + margin && y < rect[1] + rect[3] + margin
    end

    # Rooms = blobs of tiles whose 8 neighbours are all walkable, grown by one.
    def detect_rooms(lines)
      walk = layout_walk(lines)
      height = lines.length
      width = lines.map(&:size).max || 0
      interior = {}
      height.times do |y|
        width.times do |x|
          next if !walk.call(x, y)
          interior[[x, y]] = true if NEIGH8.all? { |dx, dy| walk.call(x + dx, y + dy) }
        end
      end
      rooms = []
      seen = {}
      interior.each_key do |t|
        next if seen[t]
        comp = flood(t, width, height, proc { |x, y| interior[[x, y]] })
        comp.each_key { |c| seen[c] = true }
        next if comp.size < 4
        xs = comp.keys.map { |c| c[0] }
        ys = comp.keys.map { |c| c[1] }
        rooms << [xs.min - 1, ys.min - 1, xs.max - xs.min + 3, ys.max - ys.min + 3]
      end
      return rooms.sort
    end

    def rooms(map, layout)
      lines = SeededFloors.layout_lines(layout)
      return [] if lines.empty?
      walk = layout_walk(lines)
      rects = nil
      if last_rects && last_size == [map.width, map.height]
        rects = last_rects.uniq.select do |r|
          tiles = rect_tiles(r)
          !tiles.empty? && tiles.count { |t| walk.call(t[0], t[1]) } * 5 >= tiles.size * 4
        end
      end
      rects = detect_rooms(lines) if rects.nil? || rects.empty?
      return rects.uniq.sort
    end

    #---------------------------------------------------------------------------
    # Floor analysis (RPG::Map during map setup or rebuilt from a snapshot)
    #---------------------------------------------------------------------------
    def event_index(map)
      blocked = {}
      traps = {}
      map.events.each_value do |ev|
        next if ev.x < 0 || ev.y < 0
        next if stairs?(ev) || decorative?(ev)
        traps[[ev.x, ev.y]] = ev if trap?(ev)
        blocked[[ev.x, ev.y]] = ev if blocking?(map, ev)
      end
      return blocked, traps
    end

    def reserved_region(reserved)
      region = {}
      (reserved || []).each do |res|
        rect_tiles(res[:rect]).each { |t| region[t] = true }
        (res[:entrance] || []).each { |t| region[t] = true }
      end
      return region
    end

    def reserved_owner?(reserved, ev)
      return seal?(ev) || (reserved || []).any? { |res| res[:event_id] == ev.id }
    end

    def analyze(map, layout, sx, sy, reserved = [])
      walk = SeededFloors.walkable_proc(map, layout)
      blocked, traps = event_index(map)
      free = proc { |x, y| walk.call(x, y) && !blocked[[x, y]] && !traps[[x, y]] }
      reach = flood([sx, sy], map.width, map.height, free)
      problems = []
      stairs = stairs_events(map)
      stairs.each { |ev| problems << [:stairs, ev] if !touchable?(reach, ev.x, ev.y) }
      stairs.each do |st|
        NEIGH4.each do |dx, dy|
          t = [st.x + dx, st.y + dy]
          guard = traps[t] || blocked[t]
          problems << [:stairs_guard, guard] if guard && !reserved_owner?(reserved, guard)
        end
      end
      room_list = rooms(map, layout)
      room_list.each do |r|
        tiles = rect_tiles(r).select { |t| walk.call(t[0], t[1]) }
        next if tiles.empty?
        problems << [:room, r] if tiles.none? { |t| reach.has_key?(t) }
      end
      region = reserved_region(reserved)
      map.events.values.sort_by(&:id).each do |ev|
        next if ev.x < 0
        if interactive?(ev)
          problems << [:event, ev] if !touchable?(reach, ev.x, ev.y)
          problems << [:grass, ev] if trainer?(ev) && grass_tile?(map, ev.x, ev.y)
          problems << [:decor, ev] if decor_tile?(ev.x, ev.y) && !stairs?(ev) && !reserved_owner?(reserved, ev)
        end
        if region[[ev.x, ev.y]] && !reserved_owner?(reserved, ev) && !decorative?(ev) &&
           (obstacle?(map, ev) || interactive?(ev))
          problems << [:reserved, ev]
        end
      end
      return { reach: reach, problems: problems, rooms: room_list, free: free, walk: walk }
    end

    # Tiles where an obstacle can never cut a path: all 8 neighbours walkable and
    # nothing else standing on or next to them.
    def safe_tiles(map, layout, sx, sy, reserved, ev, reach)
      walk = SeededFloors.walkable_proc(map, layout)
      occ = {}
      map.events.each_value { |e| occ[[e.x, e.y]] = true if !e.equal?(ev) && e.x >= 0 }
      occ[[sx, sy]] = true
      stairs = stairs_events(map).map { |s| [s.x, s.y] } + [[sx, sy]]
      region = reserved_region(reserved)
      grass_check = trainer?(ev) || interactive?(ev)
      reach.keys.sort.select do |t|
        x, y = t
        next false if occ[t] || region[t] || decor_tile?(x, y)
        next false if stairs.any? { |s| (s[0] - x).abs <= 2 && (s[1] - y).abs <= 2 }
        next false if (reserved || []).any? { |res| in_rect?(res[:rect], x, y, 1) }
        next false if NEIGH8.any? { |dx, dy| !walk.call(x + dx, y + dy) || occ[[x + dx, y + dy]] }
        next false if grass_check && grass_tile?(map, x, y)
        true
      end
    end

    def relocate!(map, layout, sx, sy, ev, reserved, report)
      a = analyze(map, layout, sx, sy, reserved)
      cands = safe_tiles(map, layout, sx, sy, reserved, ev, a[:reach])
      if cands.empty?
        map.events.delete(ev.id)
        report[:removed] << [ev.id, ev_name(ev)] if report
        return false
      end
      dest = cands[rand(cands.length)]
      report[:moved] << [ev.id, ev_name(ev), [ev.x, ev.y], dest] if report
      ev.x, ev.y = dest
      return true
    end

    # Obstacles on the shortest layout path from the arrival to a target.
    def path_culprits(map, layout, sx, sy, targets, reserved)
      walk = SeededFloors.walkable_proc(map, layout)
      fixed = {}
      map.events.each_value { |ev| fixed[[ev.x, ev.y]] = true if reserved_owner?(reserved, ev) }
      parents = flood([sx, sy], map.width, map.height, proc { |x, y| walk.call(x, y) && !fixed[[x, y]] })
      goal = targets.find { |t| parents.has_key?(t) }
      return [] if !goal
      blocked, traps = event_index(map)
      return trace(parents, goal).map { |t| blocked[t] || traps[t] }.compact.uniq
    end

    def problem_targets(map, layout, kind, obj)
      case kind
      when :room
        walk = SeededFloors.walkable_proc(map, layout)
        return rect_tiles(obj).select { |t| walk.call(t[0], t[1]) }
      else
        return [[obj.x, obj.y]] + NEIGH4.map { |dx, dy| [obj.x + dx, obj.y + dy] }
      end
    end

    # Carves layout-walkable tiles that decorations made impassable when they
    # cut the arrival off from other walkable ground.
    def carve_pockets!(map, layout, sx, sy)
      lines = SeededFloors.layout_lines(layout)
      return 0 if lines.empty?
      lwalk = layout_walk(lines)
      floor_tile = map.data[sx, sy, 0]
      carved = 0
      8.times do
        walk = SeededFloors.walkable_proc(map, layout)
        reach = flood([sx, sy], map.width, map.height, walk)
        parents = flood([sx, sy], map.width, map.height, lwalk)
        lost = parents.keys.find { |t| !reach.has_key?(t) && walk.call(t[0], t[1]) }
        break if !lost
        trace(parents, lost).each do |x, y|
          next if walk.call(x, y)
          map.data[x, y, 0] = floor_tile
          map.data[x, y, 1] = 0
          map.data[x, y, 2] = 0
          carved += 1
        end
      end
      return carved
    end

    def secure_floor!(map, layout, sx, sy, reserved = nil)
      reserved ||= floor_reserved || []
      report = { carved: carve_pockets!(map, layout, sx, sy), moved: [], removed: [], problems: [] }
      clear_stairs_decor!(map, layout, sx, sy, report)
      60.times do
        a = analyze(map, layout, sx, sy, reserved)
        break if a[:problems].empty?
        acted = false
        a[:problems].each do |kind, obj|
          culprits = case kind
                     when :stairs_guard, :grass, :reserved, :decor then [obj]
                     else path_culprits(map, layout, sx, sy, problem_targets(map, layout, kind, obj), reserved)
                     end
          culprits = culprits.reject { |ev| reserved_owner?(reserved, ev) }
          next if culprits.empty?
          culprits.each { |ev| relocate!(map, layout, sx, sy, ev, reserved, report) }
          acted = true
          break
        end
        break if !acted
      end
      final = analyze(map, layout, sx, sy, reserved)
      report[:problems] = final[:problems].map do |kind, obj|
        obj.is_a?(Array) ? [kind, obj] : [kind, [obj.id, ev_name(obj), obj.x, obj.y]]
      end
      report[:rooms] = final[:rooms]
      self.last_report = report
      return report
    end

    #---------------------------------------------------------------------------
    # Bounty room: single entrance, centred target, no traps
    #---------------------------------------------------------------------------
    def openings(lines, rect)
      walk = layout_walk(lines)
      x, y, w, h = rect
      ring = []
      (x...(x + w)).each { |i| ring << [i, y - 1] << [i, y + h] }
      (y...(y + h)).each { |j| ring << [x - 1, j] << [x + w, j] }
      cells = {}
      ring.each do |t|
        next if !walk.call(t[0], t[1])
        inside = NEIGH4.any? do |dx, dy|
          n = [t[0] + dx, t[1] + dy]
          in_rect?(rect, n[0], n[1]) && walk.call(n[0], n[1])
        end
        cells[t] = true if inside
      end
      groups = []
      seen = {}
      cells.each_key do |t|
        next if seen[t]
        group = []
        queue = [t]
        seen[t] = true
        until queue.empty?
          c = queue.shift
          group << c
          NEIGH8.each do |dx, dy|
            n = [c[0] + dx, c[1] + dy]
            next if !cells[n] || seen[n]
            seen[n] = true
            queue << n
          end
        end
        groups << group.sort
      end
      return groups.sort
    end

    def room_center(map, lines, rect)
      walk = layout_walk(lines)
      cx = rect[0] + (rect[2] / 2)
      cy = rect[1] + (rect[3] / 2)
      tiles = rect_tiles(rect).select do |t|
        walk.call(t[0], t[1]) && SeededFloors.tile_passable?(map, t[0], t[1]) && !grass_tile?(map, t[0], t[1])
      end
      return tiles.min_by { |t| [(t[0] - cx).abs + (t[1] - cy).abs, t[1], t[0]] }
    end

    # Layout-level connectivity: every other room and both stairs reachable
    # from the arrival when the given tiles are walls.
    def connected_without?(map, layout, sx, sy, walls, skip_rect)
      lines = SeededFloors.layout_lines(layout)
      lwalk = layout_walk(lines)
      reach = flood([sx, sy], map.width, map.height, proc { |x, y| lwalk.call(x, y) && !walls[[x, y]] })
      rooms(map, layout).each do |r|
        next if r == skip_rect
        tiles = rect_tiles(r).select { |t| lwalk.call(t[0], t[1]) && !walls[t] }
        next if tiles.empty?
        return false if tiles.none? { |t| reach.has_key?(t) }
      end
      stairs_events(map).each { |st| return false if !touchable?(reach, st.x, st.y) }
      return true
    end

    def make_seal(map, x, y)
      id = SeededFloors.next_event_id(map)
      graphic = cfg.const_defined?(:BOUNTY_SEAL_GRAPHIC) ? PMDDungeon::DataStore.setting(:FeatureConfig, :BOUNTY_SEAL_GRAPHIC) : "Object boulder"
      map.events[id] = SeededFloors.build_event(id, x, y, SEAL_NAME, nil, trigger: 0, character_name: graphic)
      return map.events[id]
    end

    # Picks (and if needed seals) a room for a bounty target. Returns
    # { rect:, center:, entrance:, seals: } or nil when no room qualifies.
    def bounty_room!(map, layout, sx, sy)
      lines = SeededFloors.layout_lines(layout)
      return nil if lines.empty?
      keep_out = stairs_events(map).map { |s| [s.x, s.y] } + [[sx, sy]]
      cands = rooms(map, layout).reject do |r|
        keep_out.any? { |k| in_rect?(r, k[0], k[1], 2) }
      end
      cands = cands.map { |r| [r, openings(lines, r)] }.reject { |_, ops| ops.empty? }
      cands = cands.shuffle(random: Random.new(rand(1 << 30))).sort_by { |_, ops| ops.length }
      cands.each do |rect, ops|
        center = room_center(map, lines, rect)
        next if !center
        if ops.length == 1
          return { rect: rect, center: center, entrance: ops[0], seals: [] } if connected_without?(map, layout, sx, sy, {}, rect)
          next
        end
        next if !cfg.const_defined?(:BOUNTY_SEAL_EXTRA_ENTRANCES) || !PMDDungeon::DataStore.setting(:FeatureConfig, :BOUNTY_SEAL_EXTRA_ENTRANCES)
        ops.each_index do |keep|
          walls = {}
          ops.each_with_index { |g, i| g.each { |t| walls[t] = true } if i != keep }
          next if !connected_without?(map, layout, sx, sy, walls, rect)
          # the room itself must still be reachable through the kept entrance
          lwalk = layout_walk(lines)
          reach = flood([sx, sy], map.width, map.height, proc { |x, y| lwalk.call(x, y) && !walls[[x, y]] })
          next if !reach.has_key?(center)
          seals = walls.keys.sort.map { |t| make_seal(map, t[0], t[1]) }
          return { rect: rect, center: center, entrance: ops[keep], seals: seals.map(&:id) }
        end
      end
      return nil
    end

    # Count of distinct entrances still open (seals count as walls).
    def open_entrances(map, layout, rect)
      lines = SeededFloors.layout_lines(layout)
      sealed = {}
      map.events.each_value { |ev| sealed[[ev.x, ev.y]] = true if seal?(ev) }
      return openings(lines, rect).reject { |g| g.all? { |t| sealed[t] } }.length
    end

    #---------------------------------------------------------------------------
    # Path finding
    #---------------------------------------------------------------------------
    # First step (2/4/6/8) of a shortest path from (sx, sy) to a tile next to
    # (tx, ty). can_step.call(x, y, dir) says whether moving from x,y in dir works.
    def bfs_next_step(sx, sy, tx, ty, width, height, max_nodes = 6000, &can_step)
      return nil if sx == tx && sy == ty
      start = [sx, sy]
      first = { start => nil }
      queue = [start]
      until queue.empty?
        cur = queue.shift
        DIRS.each do |dir, (dx, dy)|
          nx = cur[0] + dx
          ny = cur[1] + dy
          next if nx < 0 || ny < 0 || nx >= width || ny >= height
          nxt = [nx, ny]
          next if first.has_key?(nxt)
          next if nx == tx && ny == ty
          next if !can_step.call(cur[0], cur[1], dir)
          first[nxt] = first[cur] || dir
          return first[nxt] if (nx - tx).abs + (ny - ty).abs <= 1
          queue << nxt
          return nil if first.size > max_nodes
        end
      end
      return nil
    end

    def path_length(sx, sy, tx, ty, width, height, &can_step)
      dist = { [sx, sy] => 0 }
      queue = [[sx, sy]]
      until queue.empty?
        cur = queue.shift
        return dist[cur] if cur == [tx, ty]
        DIRS.each do |dir, (dx, dy)|
          nxt = [cur[0] + dx, cur[1] + dy]
          next if nxt[0] < 0 || nxt[1] < 0 || nxt[0] >= width || nxt[1] >= height
          next if dist.has_key?(nxt) || !can_step.call(cur[0], cur[1], dir)
          dist[nxt] = dist[cur] + 1
          queue << nxt
        end
      end
      return nil
    end

    # Floors a chaser passes through moving from one floor to another, as
    # [floor, stairs it leaves by] pairs, plus the stairs it emerges from.
    def cross_floor_route(from_floor, to_floor)
      return { hops: [], entry: nil } if from_floor == to_floor
      if from_floor > to_floor
        hops = from_floor.downto(to_floor + 1).map { |f| [f, :stairs_up] }
        return { hops: hops, entry: :stairs_down }
      end
      hops = from_floor.upto(to_floor - 1).map { |f| [f, :stairs_down] }
      return { hops: hops, entry: :stairs_up }
    end

    #---------------------------------------------------------------------------
    # Runtime grid on $game_map (cached per loaded floor)
    #---------------------------------------------------------------------------
    def runtime_grid
      key = [$game_map.map_id, PMDDungeon.current_floor, $game_map.data.object_id]
      return @grid if @grid_key == key
      w = $game_map.width
      h = $game_map.height
      grid = {}
      w.times do |x|
        h.times do |y|
          DIRS.each do |dir, (dx, dy)|
            nx = x + dx
            ny = y + dy
            next if nx < 0 || ny < 0 || nx >= w || ny >= h
            next if !$game_map.passable?(x, y, dir) || !$game_map.passable?(nx, ny, 10 - dir)
            grid[[x, y, dir]] = true
          end
        end
      end
      @grid_key = key
      @grid = grid
      return grid
    end

    def runtime_blockers(except = nil)
      occ = {}
      $game_map.events.each_value do |ev|
        next if ev.equal?(except) || ev.through || ev.character_name.to_s == ""
        next if ev.respond_to?(:erased?) ? ev.erased? : ev.instance_variable_get(:@erased)
        occ[[ev.x, ev.y]] = true
      end
      return occ
    end

    def chase_step(ev)
      return ev.move_random if PMDDungeon::Features.hidden?
      px = $game_player.x
      py = $game_player.y
      if (ev.x - px).abs + (ev.y - py).abs <= 1
        ev.turn_toward_player
        ev.move_toward_player   # bumping into the player fires the touch trigger
        return
      end
      grid = runtime_grid
      occ = runtime_blockers(ev)
      dir = bfs_next_step(ev.x, ev.y, px, py, $game_map.width, $game_map.height) do |x, y, d|
        dx, dy = DIRS[d]
        grid[[x, y, d]] && !occ[[x + dx, y + dy]]
      end
      if dir
        step_over_hidden(ev, dir)
      else
        ev.move_toward_player
      end
    end

    # Game_Character#passable? lets any non-through event block other events,
    # even graphic-less ones (hidden traps, stairs). The chase path only avoids
    # visible blockers, so the chaser walks over hidden events (the map tiles
    # were already checked through runtime_grid).
    def step_over_hidden(ev, dir)
      dx, dy = DIRS[dir]
      nx = ev.x + dx
      ny = ev.y + dy
      hidden = $game_map.events.values.any? do |e|
        !e.equal?(ev) && e.x == nx && e.y == ny && !e.through && e.character_name.to_s == ""
      end
      return ev.move_generic(dir) if !hidden || ev.through
      ev.through = true
      begin
        return ev.move_generic(dir)
      ensure
        ev.through = false
      end
    end

    # Reachable tile far from the player (for spawning a hunter).
    def far_reachable_tile(min_dist = 8)
      grid = runtime_grid
      occ = runtime_blockers
      start = [$game_player.x, $game_player.y]
      dist = { start => 0 }
      queue = [start]
      until queue.empty?
        cur = queue.shift
        DIRS.each do |dir, (dx, dy)|
          nxt = [cur[0] + dx, cur[1] + dy]
          next if dist.has_key?(nxt) || !grid[[cur[0], cur[1], dir]] || occ[nxt]
          dist[nxt] = dist[cur] + 1
          queue << nxt
        end
      end
      cands = dist.select { |_, d| d >= min_dist }
      return nil if cands.empty?
      best = cands.values.max
      far = cands.select { |_, d| d >= best / 2 }.keys.sort
      return far[rand(far.length)]
    end

    # Free tile next to the given stairs event on $game_map, away from the player.
    def tile_beside_stairs(kind)
      st = $game_map.events.values.find do |ev|
        n = ev.name.to_s
        kind == :stairs_up ? n[/\Astairs_up\z/i] : (n[/stairs/i] && !n[/stairs_up|ladder_top/i])
      end
      return nil if !st
      occ = runtime_blockers
      grid = runtime_grid
      spots = DIRS.map { |dir, (dx, dy)| [st.x + dx, st.y + dy, dir] }.select do |x, y, dir|
        grid[[st.x, st.y, dir]] && !occ[[x, y]] && !($game_player.x == x && $game_player.y == y)
      end
      spots = spots.map { |x, y, _| [x, y] }
      return nil if spots.empty?
      return spots.max_by { |x, y| [(x - $game_player.x).abs + (y - $game_player.y).abs, -y, -x] }
    end

    #---------------------------------------------------------------------------
    # Validation of a stored floor (debug menu / tests)
    #---------------------------------------------------------------------------
    def validate_snapshot(floor)
      snap = SeededFloors.snapshots[floor]
      return nil if !snap
      map = RPG::Map.new(snap[:width], snap[:height])
      map.tileset_id = snap[:tileset_id] if snap[:tileset_id]
      map.data = Marshal.load(snap[:data])
      map.events = Marshal.load(snap[:events])
      SeededFloors.floor_state(floor)[:consumed].each { |id| map.events.delete(id) }
      up = map.events.values.find { |ev| ev.name.to_s[/\Astairs_up\z/i] }
      return { ok: false, problems: [[:no_stairs_up, nil]] } if !up
      saved_rects = last_rects
      saved_decor = last_decor
      self.last_rects = snap[:rooms]
      self.last_size = [snap[:width], snap[:height]]
      self.last_decor = snap[:decor] || {}
      a = analyze(map, snap[:layout], up.x, up.y, snap[:reserved] || [])
      self.last_rects = saved_rects
      self.last_decor = saved_decor
      decor_problems = stairs_events(map).select { |st| (snap[:decor] || {}).key?([st.x, st.y]) }
      a[:problems].concat(decor_problems.map { |st| [:stairs_on_decoration, st] })
      down = stairs_events(map).find { |ev| !ev.name.to_s[/\Astairs_up\z/i] }
      route = nil
      if down
        walk = SeededFloors.walkable_proc(map, snap[:layout])
        route = path_length(up.x, up.y, down.x, down.y, map.width, map.height) do |x, y, d|
          dx, dy = DIRS[d]
          walk.call(x + dx, y + dy) || (x + dx == down.x && y + dy == down.y)
        end
      end
      problems = a[:problems].map { |k, o| o.is_a?(Array) ? [k, o] : [k, [o.id, ev_name(o), o.x, o.y]] }
      return { ok: problems.empty? && !down.nil?, problems: problems, rooms: a[:rooms].length,
               stairs_up: [up.x, up.y], stairs_down: down ? [down.x, down.y] : nil, route: route }
    end
  end
end

#===============================================================================
# Generator hooks (RandomDungeons loads before this file)
#===============================================================================
if defined?(RandomDungeon::Dungeon)
  class RandomDungeon::Dungeon
    alias pmd_layout_generate_layout generate_layout unless method_defined?(:pmd_layout_generate_layout)
    def generate_layout(*args)
      @room_rects = []   # rects of discarded redraw attempts must not leak into event placement
      return pmd_layout_generate_layout(*args)
    end

    alias pmd_layout_place_patch place_patch unless method_defined?(:pmd_layout_place_patch)
    def place_patch(type, *args)
      return pmd_layout_place_patch(type, *args) if type != :floor_patch || !@parameters
      old = @parameters.floor_patch_chance
      @parameters.instance_variable_set(:@floor_patch_chance, PMDDungeon::Layout.scaled_patch_chance(old))
      begin
        return pmd_layout_place_patch(type, *args)
      ensure
        @parameters.instance_variable_set(:@floor_patch_chance, old)
      end
    end

    alias pmd_layout_generate generate unless method_defined?(:pmd_layout_generate)
    def generate(*args)
      ret = pmd_layout_generate(*args)
      PMDDungeon::Layout.capture(self)
      return ret
    end
  end
end

class Game_Event
  alias pmd_layout_move_type_toward_player move_type_toward_player unless method_defined?(:pmd_layout_move_type_toward_player)
  def move_type_toward_player
    return PMDDungeon::Layout.chase_step(self) if @pmd_chaser
    pmd_layout_move_type_toward_player
  end
end
