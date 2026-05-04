class PokemonPokedexInfo_Scene
  # Everything for the MOVES page lives here.
  # Keeps tweaks local and easier to maintain.
  #-----------------------------------------------------------------------------
  # Layout values for quick pixel adjustments.
  #-----------------------------------------------------------------------------
  def moves_list_panel_x
    return 24
  end

  def moves_list_panel_y
    return 48
  end

  def moves_list_panel_width
    return 212
  end

  def moves_list_panel_height
    return 212
  end

  def moves_info_panel_x
    return 276
  end

  def moves_info_panel_y
    return 48
  end

  def moves_info_panel_width
    return Graphics.width - moves_info_panel_x - 24
  end

  def moves_info_panel_height
    return 152
  end

  def moves_desc_panel_x
    return 46
  end

  def moves_desc_panel_y
    return 280
  end

  def moves_desc_panel_width
    return 420
  end

  def moves_desc_panel_height
    return 90
  end

  def moves_line_height
    return 20
  end

  #-----------------------------------------------------------------------------
  # Build move data used by this page.
  # Keep source + level so each list can be shown correctly.
  #-----------------------------------------------------------------------------
  def pbGetMovesData(species, form)
    moves = []
    species_data = GameData::Species.get_species_form(species, form) || GameData::Species.try_get(species)
    return moves unless species_data

    # Avoid duplicates when a move appears in more than one source.
    move_ids_seen = []

    # Level-up moves (with level values for the left tag).
    Array(species_data.moves).each do |entry|
      level, move_id = entry
      next unless move_id
      next if move_ids_seen.include?(move_id)
      move_data = GameData::Move.get(move_id) rescue nil
      next unless move_data
      move_ids_seen.push(move_id)
      moves.push({
        :id       => move_id,
        :name     => move_data.name,
        :source   => :level,
        :level    => level || 0,
        :category => (move_data.respond_to?(:category) ? move_data.category : 2)
      })
    end

    # Tutor moves (still deduplicated).
    Array(species_data.tutor_moves).each do |move_id|
      next if move_ids_seen.include?(move_id)
      move_data = GameData::Move.get(move_id) rescue nil
      next unless move_data
      move_ids_seen.push(move_id)
      moves.push({
        :id       => move_id,
        :name     => move_data.name,
        :source   => :tutor,
        :level    => nil,
        :category => (move_data.respond_to?(:category) ? move_data.category : 2)
      })
    end

    # Egg moves (still deduplicated).
    Array(species_data.egg_moves).each do |move_id|
      next if move_ids_seen.include?(move_id)
      move_data = GameData::Move.get(move_id) rescue nil
      next unless move_data
      move_ids_seen.push(move_id)
      moves.push({
        :id       => move_id,
        :name     => move_data.name,
        :source   => :egg,
        :level    => nil,
        :category => (move_data.respond_to?(:category) ? move_data.category : 2)
      })
    end

    return moves
  end

  #-----------------------------------------------------------------------------
  # Rebuild cached move lists when species/form changes.
  #-----------------------------------------------------------------------------
  def pbRefreshMovesPageData
    # Skip work if species/form is unchanged.
    changed = (@moves_page_species != @species || @moves_page_form != @form || !@moves_page_data)
    return unless changed

    @moves_page_data = pbGetMovesData(@species, @form)

    # Level list: level first, then name.
    @moves_level_list = @moves_page_data.select { |entry| entry[:source] == :level }
    @moves_level_list.sort_by! { |entry| [entry[:level] || 0, entry[:name]] }

    # Other moves: split by category, sorted by name.
    sorted_all_moves = @moves_page_data.sort_by { |entry| entry[:name] }
    @moves_other_lists = [
      sorted_all_moves.select { |entry| entry[:category] == 0 },
      sorted_all_moves.select { |entry| entry[:category] == 1 },
      sorted_all_moves.select { |entry| entry[:category] == 2 }
    ]

    # Reset cursor state when changing Pokemon.
    @moves_page_mode = :level
    @moves_page_category = 0
    @moves_page_index = 0
    @moves_page_offset = 0
    @moves_page_interacting = false

    @moves_page_species = @species
    @moves_page_form = @form
  end

  #-----------------------------------------------------------------------------
  # Return the currently visible move list.
  #-----------------------------------------------------------------------------
  def pbActiveMovesList
    # Single source of truth for draw/input code.
    if @moves_page_mode == :level
      return @moves_level_list || []
    end
    return (@moves_other_lists && @moves_other_lists[@moves_page_category]) ? @moves_other_lists[@moves_page_category] : []
  end

  #-----------------------------------------------------------------------------
  # Keep cursor index valid and on-screen.
  #-----------------------------------------------------------------------------
  def pbEnsureMovesIndexVisible
    list = pbActiveMovesList
    # Empty list should always point to index 0.
    @moves_page_index = 0 if list.empty?
    @moves_page_index = [[@moves_page_index, 0].max, list.length - 1].min if !list.empty?

    available_height = moves_list_panel_height - 64
    shown = [available_height / moves_line_height, 1].max

    # Scroll up if cursor goes above the window.
    if @moves_page_index < @moves_page_offset
      @moves_page_offset = @moves_page_index
    # Scroll down if cursor goes below the window.
    elsif @moves_page_index >= @moves_page_offset + shown
      @moves_page_offset = @moves_page_index - shown + 1
    end

    @moves_page_offset = [@moves_page_offset, 0].max
  end

  #-----------------------------------------------------------------------------
  # Create the list arrow once.
  #-----------------------------------------------------------------------------
  def pbEnsureMovesArrow
    # Lazy init keeps redraws cheap.
    return if @sprites["moves_arrow"]
    @sprites["moves_arrow"] = BitmapSprite.new(24, 24, @viewport)
    arrow_bitmap = @sprites["moves_arrow"].bitmap
    arrow_bitmap.font.size = 26
    arrow_bitmap.font.color = Color.new(64, 32, 16)
    arrow_bitmap.draw_text(0, 0, 24, 24, ">")
    @sprites["moves_arrow"].visible = false
  end

  #-----------------------------------------------------------------------------
  # Generic panel helper.
  #-----------------------------------------------------------------------------
  def pbDrawMovesPanel(bitmap, x, y, width, height, fill_color, border_color)
    # Shared panel style helper.
    bitmap.fill_rect(x, y, width, height, border_color)
    bitmap.fill_rect(x + 2, y + 2, width - 4, height - 4, fill_color)
  end

  #-----------------------------------------------------------------------------
  # Trim short text so it fits in stat boxes.
  #-----------------------------------------------------------------------------
  def pbTrimMovesTextToBox(bitmap, text, max_width, max_height)
    # Keep this ready if we add strict height rules later.
    # Save original font size.
    orig_size = bitmap.font.size
    bitmap.font.size = 14
    
    # Trim to width.
    trimmed = text.dup
    while trimmed.length > 0 && bitmap.text_size(trimmed).width > max_width
      trimmed = trimmed[0...-1]
    end
    
    # Add ellipsis if trimmed.
    if trimmed.length < text.length && trimmed.length > 0
      while trimmed.length > 0 && bitmap.text_size(trimmed + "...").width > max_width
        trimmed = trimmed[0...-1]
      end
      trimmed = trimmed + "..." if trimmed.length > 0
    end
    
    bitmap.font.size = orig_size
    return trimmed
  end

  #-----------------------------------------------------------------------------
  # Trim long move names to stay inside list rows.
  #-----------------------------------------------------------------------------
  def pbTrimMovesText(bitmap, text, max_width)
    # Keep long names inside the row.
    return text if bitmap.text_size(text).width <= max_width
    base_text = text.dup
    while base_text.length > 1
      base_text = base_text[0...-1]
      test_text = base_text + "..."
      return test_text if bitmap.text_size(test_text).width <= max_width
    end
    return text
  end

  #-------------------------------------------------------------------------------
  # Format move power text to fir context
  #-------------------------------------------------------------------------------
  def pbFormatMovePower(move_data)
    return "-" unless move_data.respond_to?(:power) && move_data.power
    return "?" if move_data.power == 1
    return move_data.power.to_s if move_data.power > 0
    return "-"
  end

  #-----------------------------------------------------------------------------
  # Wrap text by width.
  #-----------------------------------------------------------------------------
  def pbWrapMovesDescriptionText(bitmap, text, max_width)
    return [""] if text.nil? || text.empty?
    words = text.split(/\s+/)
    return [""] if words.empty?

    lines = []
    current = ""
    words.each do |word|
      candidate = current.empty? ? word : "#{current} #{word}"
      if bitmap.text_size(candidate).width <= max_width
        current = candidate
      else
        lines.push(current) unless current.empty?
        if bitmap.text_size(word).width <= max_width
          current = word
        else
          # If one word is too long, split it.
          fragment = ""
          word.each_char do |ch|
            next_fragment = fragment + ch
            if bitmap.text_size(next_fragment).width <= max_width
              fragment = next_fragment
            else
              lines.push(fragment) unless fragment.empty?
              fragment = ch
            end
          end
          current = fragment
        end
      end
    end
    lines.push(current) unless current.empty?
    return lines
  end

  #-----------------------------------------------------------------------------
  # Fit description text inside a box.
  # Try bigger font first, shrink only if needed.
  #-----------------------------------------------------------------------------
  def pbFitMovesDescriptionText(bitmap, text, max_width, max_height)
    min_size = 11
    max_size = 18

    max_size.downto(min_size) do |size|
      bitmap.font.size = size
      line_height = bitmap.text_size("Ay").height + 2
      max_lines = [max_height / line_height, 1].max
      lines = pbWrapMovesDescriptionText(bitmap, text, max_width)
      if lines.length <= max_lines
        return [size, lines]
      end
    end

    # Last fallback: minimum size + ellipsis.
    bitmap.font.size = min_size
    line_height = bitmap.text_size("Ay").height + 2
    max_lines = [max_height / line_height, 1].max
    lines = pbWrapMovesDescriptionText(bitmap, text, max_width)
    lines = lines[0, max_lines]
    if lines && !lines.empty?
      lines[-1] = pbTrimMovesText(bitmap, lines[-1], max_width)
      if bitmap.text_size(lines[-1] + "...").width <= max_width
        lines[-1] += "..."
      end
    end
    return [min_size, lines]
  end

  #-----------------------------------------------------------------------------
  # Convert move source to short left tag text.
  #-----------------------------------------------------------------------------
  def pbGetMovesSourceText(entry)
    # Level 0 is shown as "E".
    case entry[:source]
    when :level then (entry[:level] == 0 ? _INTL("E") : entry[:level].to_s)
    when :tutor then _INTL("TM")
    when :egg   then _INTL("EG")
    else             _INTL("--")
    end
  end

  #-----------------------------------------------------------------------------
  # Draw left list panel.
  #-----------------------------------------------------------------------------
  def pbDrawMovesListPanel(overlay)
    title_base   = Color.new(248, 248, 248)
    title_shadow = Color.new(168, 120, 52)
    text_base    = Color.new(32, 24, 8)
    text_shadow  = Color.new(236, 224, 202)
    dim_base     = Color.new(64, 48, 16)
    dim_shadow   = Color.new(236, 224, 202)
    white_bg     = Color.new(255, 250, 235, 65)
    black_bg     = Color.new(224, 160, 56, 35)

    if @moves_page_mode == :other
      # Show category title while in Other mode.
      cat_names = [_INTL("Physical"), _INTL("Special"), _INTL("Status")]
      category_text = _INTL("< {1} >", cat_names[@moves_page_category])
      drawFormattedTextEx(overlay, moves_list_panel_x + 12, moves_list_panel_y + 18, moves_list_panel_width - 24, "<ac><b>#{category_text}</b></ac>", dim_base, dim_shadow)
    end

    list = pbActiveMovesList
    if list.empty?
      # Fallback when this list is empty.
      drawFormattedTextEx(overlay, moves_list_panel_x + 12, moves_list_panel_y + 50, moves_list_panel_width - 24, _INTL("No moves in this list."), text_base, text_shadow)
      @sprites["moves_arrow"].visible = false if @sprites["moves_arrow"]
      return
    end

    pbEnsureMovesIndexVisible

    start_y = moves_list_panel_y + ((@moves_page_mode == :other) ? 40 : 16)
    available_height = moves_list_panel_height - (start_y - moves_list_panel_y) - 10
    shown = [available_height / moves_line_height, 1].max

    # Alternate row backgrounds.
    window = list[@moves_page_offset, shown] || []
    window.each_with_index do |entry, i|
      draw_y = start_y + i * moves_line_height
      bg_color = (i % 2 == 0) ? white_bg : black_bg
      overlay.fill_rect(moves_list_panel_x + 2, draw_y, moves_list_panel_width - 4, moves_line_height, bg_color)
    end

    # Draw row text.
    overlay.font.size = 18
    row_nudge_y = 6
    textpos = []
    window.each_with_index do |entry, i|
      draw_y = start_y + i * moves_line_height
      text_height = overlay.text_size("Ag").height
      text_y = draw_y + [(moves_line_height - text_height) / 2, 0].max + row_nudge_y
      source_text = pbGetMovesSourceText(entry)
      entry_base = Color.new(0, 0, 0)
      entry_shadow = Color.new(236, 230, 214)

      line_x = moves_list_panel_x + 22
      if @moves_page_mode == :level
        # Leave room for level tag on the left.
        name_text = pbTrimMovesText(overlay, entry[:name], moves_list_panel_width - 80)
        textpos.push([source_text, line_x, text_y, :left, entry_base, entry_shadow])
        textpos.push([name_text, line_x + 36, text_y, :left, entry_base, entry_shadow])
      else
        name_text = pbTrimMovesText(overlay, entry[:name], moves_list_panel_width - 40)
        textpos.push([name_text, line_x, text_y, :left, entry_base, entry_shadow])
      end
    end
    pbDrawTextPositions(overlay, textpos)
    overlay.font.size = 24

    pbEnsureMovesArrow
    @sprites["moves_arrow"].x = moves_list_panel_x + 4
    arrow_nudge_y = -4
    row_y = start_y + (@moves_page_index - @moves_page_offset) * moves_line_height
    arrow_h = @sprites["moves_arrow"].bitmap.height
    @sprites["moves_arrow"].y = row_y + ((moves_line_height - arrow_h) / 2).floor + arrow_nudge_y
    @sprites["moves_arrow"].visible = @moves_page_interacting
  end

  #-----------------------------------------------------------------------------
  # Draw right panel with move stats.
  #-----------------------------------------------------------------------------
  def pbDrawMovesInfoPanel(overlay)
    title_base   = Color.new(32, 24, 8)
    title_shadow = Color.new(238, 228, 210)
    text_base    = Color.new(40, 40, 56)
    text_shadow  = Color.new(236, 236, 242)
    stat_base    = Color.new(90, 64, 24)
    stat_shadow  = Color.new(236, 224, 202)

    unless @moves_page_interacting
      return
    end

    list = pbActiveMovesList
    return if list.empty?
    entry = list[@moves_page_index]
    return unless entry

    move_data = GameData::Move.get(entry[:id]) rescue nil
    return unless move_data

    # Clean display values so empty stats show "-".
    move_name = pbTrimMovesText(overlay, move_data.name, moves_info_panel_width - 24)
    move_type = move_data.type ? (GameData::Type.get(move_data.type).name rescue "-") : "-"
    move_cat = case move_data.category
               when 0 then _INTL("Physical")
               when 1 then _INTL("Special")
               else        _INTL("Status")
               end
    move_power = pbFormatMovePower(move_data)
    move_accuracy = (move_data.respond_to?(:accuracy) && move_data.accuracy && move_data.accuracy > 0) ? "#{move_data.accuracy}%" : "-"
    move_priority = (move_data.respond_to?(:priority) && !move_data.priority.nil?) ? move_data.priority.to_s : "0"

    info_nudge_y = 4
    left = moves_info_panel_x + 8
    top = moves_info_panel_y + 12 + info_nudge_y
    width = moves_info_panel_width - 16

    overlay.font.size = 16
    drawFormattedTextEx(overlay, left, top, width, "<b>#{move_name}</b>", title_base, title_shadow)
    overlay.font.size = 24

    # Draw the panel artwork behind stat text.
    panels_x = moves_info_panel_x + 13
    panels_y = moves_info_panel_y + 42 + info_nudge_y
    pbDrawImagePositions(overlay, [["Graphics/UI/Pokedex/Panels_move_dex", panels_x, panels_y]])

    # Top row: TYPE, CATEGORY, POWER.
    # Bottom row: PRIO, ACC.
    overlay.font.size = 13
    textpos = []
    top_label_y = panels_y + 16
    top_value_y = panels_y + 30
    bottom_label_y = panels_y + 54
    bottom_value_y = panels_y + 68

    textpos.push([_INTL("TYPE"),      panels_x + 6,   top_label_y,    :left, stat_base, stat_shadow])
    textpos.push([_INTL("CATEGORY"),  panels_x + 72,  top_label_y,    :left, stat_base, stat_shadow])
    textpos.push([_INTL("POWER"),     panels_x + 137, top_label_y,    :left, stat_base, stat_shadow])

    textpos.push([pbTrimMovesTextToBox(overlay, move_type, 48, 12),     panels_x + 6,   top_value_y,    :left, title_base, title_shadow])
    textpos.push([pbTrimMovesTextToBox(overlay, move_cat, 58, 12),      panels_x + 72,  top_value_y,    :left, title_base, title_shadow])
    textpos.push([pbTrimMovesTextToBox(overlay, move_power, 44, 12),    panels_x + 137, top_value_y,    :left, title_base, title_shadow])

    textpos.push([_INTL("PRIO"), panels_x + 72,  bottom_label_y, :left, stat_base, stat_shadow])
    textpos.push([_INTL("ACC"),  panels_x + 137, bottom_label_y, :left, stat_base, stat_shadow])
    textpos.push([pbTrimMovesTextToBox(overlay, move_priority, 58, 12), panels_x + 72,  bottom_value_y, :left, title_base, title_shadow])
    textpos.push([pbTrimMovesTextToBox(overlay, move_accuracy, 44, 12), panels_x + 137, bottom_value_y, :left, title_base, title_shadow])

    pbDrawTextPositions(overlay, textpos)
    overlay.font.size = 24
  end

  #-----------------------------------------------------------------------------
  # Draw bottom move description panel.
  #-----------------------------------------------------------------------------
  def pbDrawMovesDescriptionPanel(overlay)
    title_base   = Color.new(32, 24, 8)
    title_shadow = Color.new(238, 228, 210)

    unless @moves_page_interacting
      return
    end

    list = pbActiveMovesList
    return if list.empty?
    entry = list[@moves_page_index]
    return unless entry

    move_data = GameData::Move.get(entry[:id]) rescue nil
    return unless move_data
    description = ""
    description = move_data.description if move_data.respond_to?(:description) && move_data.description

    # Start big, shrink only if needed to fit.
    text_x = moves_desc_panel_x + 8
    text_y = moves_desc_panel_y + 16
    text_w = moves_desc_panel_width - 16
    text_h = moves_desc_panel_height - 16

    font_size, lines = pbFitMovesDescriptionText(overlay, description.to_s, text_w, text_h)
    overlay.font.size = font_size
    line_height = overlay.text_size("Ay").height + 2
    textpos = []
    lines.each_with_index do |line, i|
      draw_y = text_y + i * line_height
      next if draw_y + line_height > text_y + text_h
      textpos.push([line, text_x, draw_y, :left, Color.new(24, 24, 24), Color.new(232, 232, 232)])
    end
    pbDrawTextPositions(overlay, textpos)
    overlay.font.size = 24
  end

  #-----------------------------------------------------------------------------
  # Optional mode header text.
  #-----------------------------------------------------------------------------
  def pbDrawMovesModeHeader(overlay)
    title_base   = Color.new(248, 248, 248)
    title_shadow = Color.new(136, 80, 16)

    if @moves_page_mode == :level
      mode_text = _INTL("LEVEL UP MOVES")
    else
      # Show current Other category.
      cat_names = [_INTL("Physical"), _INTL("Special"), _INTL("Status")]
      mode_text = _INTL("OTHER MOVES: {1}", cat_names[@moves_page_category])
    end

    overlay.font.size = 19
    drawFormattedTextEx(overlay, 12, 8, Graphics.width - 24, "<b>#{mode_text}</b>", title_base, title_shadow)
    overlay.font.size = 24
  end

  #-----------------------------------------------------------------------------
  # Custom draw entry for this page.
  #-----------------------------------------------------------------------------
  alias modular_old_drawPageMoves drawPageMoves
  def drawPageMoves
    overlay = @sprites["overlay"].bitmap
    pbRefreshMovesPageData
    pbDrawMovesListPanel(overlay)
    pbDrawMovesInfoPanel(overlay)
    pbDrawMovesDescriptionPanel(overlay)
  end

  #-----------------------------------------------------------------------------
  # Focused move browsing mode.
  # Controls:
  #   UP/DOWN    = move selection
  #   LEFT/RIGHT = switch category in OTHER mode, or switch to OTHER from LEVEL mode
  #   BACK       = leave inspection mode
  #-----------------------------------------------------------------------------
  def pbScrollMoves
    # Main input loop for the page.
    pbRefreshMovesPageData
    @moves_page_interacting = true
    drawPage(@page)

    loop do
      Graphics.update
      Input.update
      pbUpdate

      if Input.trigger?(Input::BACK)
        # Exit focused mode.
        pbPlayCloseMenuSE
        break
      elsif Input.repeat?(Input::UP)
        list = pbActiveMovesList
        next if list.empty?
        pbPlayCursorSE
        @moves_page_index -= 1
        @moves_page_index = list.length - 1 if @moves_page_index < 0
        drawPage(@page)
      elsif Input.repeat?(Input::DOWN)
        list = pbActiveMovesList
        next if list.empty?
        pbPlayCursorSE
        @moves_page_index += 1
        @moves_page_index = 0 if @moves_page_index >= list.length
        drawPage(@page)
      elsif Input.repeat?(Input::LEFT)
        if @moves_page_mode == :other
          pbPlayCursorSE
          # Wrap from first Other category back to Level.
          if @moves_page_category == 0
            @moves_page_mode = :level
          else
            # Otherwise move to previous category.
            @moves_page_category -= 1
          end
          @moves_page_index = 0
          @moves_page_offset = 0
          drawPage(@page)
        elsif @moves_page_mode == :level
          pbPlayCursorSE
          # From Level, LEFT enters Other at last category.
          @moves_page_mode = :other
          @moves_page_category = 2
          @moves_page_index = 0
          @moves_page_offset = 0
          drawPage(@page)
        end
      elsif Input.repeat?(Input::RIGHT)
        if @moves_page_mode == :level
          pbPlayCursorSE
          # From Level, RIGHT enters Other at first category.
          @moves_page_mode = :other
          @moves_page_category = 0
          @moves_page_index = 0
          @moves_page_offset = 0
          drawPage(@page)
        elsif @moves_page_mode == :other
          pbPlayCursorSE
          # Wrap from last Other category back to Level.
          if @moves_page_category == 2
            @moves_page_mode = :level
          else
            # Otherwise move to next category.
            @moves_page_category += 1
          end
          @moves_page_index = 0
          @moves_page_offset = 0
          drawPage(@page)
        end
      end
    end

    @moves_page_interacting = false
    @sprites["moves_arrow"].visible = false if @sprites["moves_arrow"]
    drawPage(@page)
  end

  #-----------------------------------------------------------------------------
  # While on MOVES, UP/DOWN changes move, not species.
  #-----------------------------------------------------------------------------
  alias modular_moves_page_go_to_previous pbGoToPrevious
  def pbGoToPrevious
    if @page_id == :page_moves
      # On this page, previous = previous move.
      pbRefreshMovesPageData
      list = pbActiveMovesList
      return if list.empty?
      @moves_page_interacting = true
      @moves_page_index -= 1
      @moves_page_index = list.length - 1 if @moves_page_index < 0
      drawPage(@page)
      return
    end
    modular_moves_page_go_to_previous
  end

  alias modular_moves_page_go_to_next pbGoToNext
  def pbGoToNext
    if @page_id == :page_moves
      # On this page, next = next move.
      pbRefreshMovesPageData
      list = pbActiveMovesList
      return if list.empty?
      @moves_page_interacting = true
      @moves_page_index += 1
      @moves_page_index = 0 if @moves_page_index >= list.length
      drawPage(@page)
      return
    end
    modular_moves_page_go_to_next
  end

  #-----------------------------------------------------------------------------
  # USE key opens focused move browsing.
  #-----------------------------------------------------------------------------
  if method_defined?(:pbPageCustomUse)
    alias modular_moves_page_custom_use pbPageCustomUse
  end

  def pbPageCustomUse(page_id)
    if page_id == :page_moves
      # Enter focused mode.
      pbPlayDecisionSE
      pbScrollMoves
      return true
    end
    return modular_moves_page_custom_use(page_id) if defined?(modular_moves_page_custom_use)
    return false
  end
end