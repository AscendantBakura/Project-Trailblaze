#===============================================================================
# Adds/edits various Summary utilities.
#===============================================================================
class PokemonSummary_Scene
  #===============================================================================
  # Draws the Held Items summary page
  #===============================================================================
  def drawPageItems
    overlay = @sprites["overlay"].bitmap
    base   = Color.new(248, 248, 248)
    shadow = Color.new(72, 72, 72)
    textpos = []
    button_id = 1#0

    # Category Y positions
    category_positions = {
      Offensive: 48,
      Defensive: 120,
      Utility:   192,
      Extra:     264
    }

    # Map categories to items (nil if none)
    items_by_cat = {
      Offensive: nil,
      Defensive: nil,
      Utility:   nil,
      Extra:     nil
    }

    # Assign items into their categories
    @pokemon.items.each do |item|
      cat = pbItemCategory(item)
      items_by_cat[cat] = item
    end

    # Draw each held item (icon + name + button)
    items_by_cat.each_with_index do |(cat, item), i|
      #next if !item
      y = category_positions[cat]

      if item
        # Get item data
        item_data = GameData::Item.get(item)
        item_name = item_data.name

        # Load and draw item icon (using same reference logic as drawPageOne)
        icon_path = GameData::Item.icon_filename(item)
        bmp = RPG::Cache.load_bitmap("", icon_path)
        overlay.blt(232, y, bmp, bmp.rect)   # Icon position
        bmp.dispose
      else
        item_name = "No item"
      end

      # Draw item name (aligned beside icon)
      textpos.push([item_name, 292, y, 0, Color.new(246, 198, 6), Color.new(74, 97, 103)])

      # Draw Details button
      drawButton(overlay, 334, y + 24, "Details", button_id)
      #button_id += 1
    end

    pbDrawTextPositions(overlay, textpos)
  end
  
  #===============================================================================
  # Shows detailed info for held items (with cycling)
  #===============================================================================
  def pbItemPrompt(start_index = 0)
    # Prepare overlays
    @sprites["promptoverlay"].bitmap.clear
    @sprites["promptoverlay"].visible = true
    @sprites["itembg"].visible = true
    overlay = @sprites["promptoverlay"].bitmap
    base   = Color.new(246, 198, 6)
    shadow = Color.new(74, 97, 103)

    # Get all held items
    items = @pokemon.items
    return if items.nil? || items.empty?

    index = start_index % items.length

    loop do
      overlay.clear
      item = items[index]
      item_data = GameData::Item.get(item)

      # Display icon if you have a sprite prepared
      if @sprites["itemicondesc"]
        @sprites["itemicondesc"].item = item
        @sprites["itemicondesc"].visible = true
      end

      # Draw title and name
      textpos = [
        [_INTL("Held Item"), 256, 86, :center, base, shadow],
        [item_data.name, 256, 118, :center, Color.new(248, 248, 248), Color.new(74, 112, 175)]
      ]
      drawButton(overlay, 180, 276, "Close", 2)
      pbDrawTextPositions(overlay, textpos)

      # Use held_description if DBK Z-Power plugin installed
      desc = if PluginManager.installed?("[DBK] Z-Power")
               item_data.held_description || item_data.description
             else
               item_data.description
             end

      # Draw description text
      drawTextEx(overlay, 50, 152, 416, 4, desc, Color.new(248, 248, 248), Color.new(74, 112, 175))

      # Handle input
      Graphics.update
      Input.update
      pbUpdate

      if Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::UP) && items.length > 1
        index = (index - 1) % items.length
        pbPlayCursorSE
      elsif Input.trigger?(Input::DOWN) && items.length > 1
        index = (index + 1) % items.length
        pbPlayCursorSE
      end
    end

    # Hide elements again
    @sprites["itembg"].visible = false
    @sprites["itemicondesc"].visible = false if @sprites["itemicondesc"]
    @sprites["promptoverlay"].visible = false
  end
  
end