#===============================================================================
# * Gacha System Details UI
#===============================================================================

class GachaDetails_Scene
  def pbStartScene(banner_id)
    @banner_id = banner_id
    @banner = GachaConfig::BANNERS[banner_id]
    
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    
    @anim_frame = 0
    @anim_timer = 0
    
    @star_bmp = pbResolveBitmap("Graphics/UI/Gacha/star") ? Bitmap.new("Graphics/UI/Gacha/star") : nil
    
    # Background
    @sprites["background"] = Sprite.new(@viewport)
    @sprites["background"].bitmap = Bitmap.new(Graphics.width, Graphics.height)
    @sprites["background"].bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(20, 20, 20))
    
    # Header Overlay
    @sprites["header"] = Sprite.new(@viewport)
    @sprites["header"].bitmap = Bitmap.new(Graphics.width, 48)
    @sprites["header"].bitmap.fill_rect(0, 0, Graphics.width, 48, Color.new(40, 40, 60))
    pbSetSystemFont(@sprites["header"].bitmap)
    
    textPos = [
      [_INTL("{1} - Prize Rates", @banner[:name]), Graphics.width / 2, 8, 2, Color.new(248, 248, 248), Color.new(20, 20, 20)]
      ]
    pbDrawTextPositions(@sprites["header"].bitmap, textPos)

    pbCalculateData
    pbCreateList
    
    pbFadeInAndShow(@sprites)
  end
  
  def pbCalculateData
    @prize_data = []
    return if !@banner || !@banner[:pools]
    
    total_weight = 0
    @banner[:pools].each { |p| total_weight += p[:probability] }
    
    return if total_weight == 0
    
    @banner[:pools].each do |prize|
      pct = (prize[:probability].to_f / total_weight.to_f) * 100.0
      
      name = ""
      icon_bmp = nil
      
      if prize[:type] == :pokemon
        name = GameData::Species.get(prize[:species]).name
        name += _INTL(" (Lv. {1})", prize[:level]) if prize[:level]
        # Using the standard icon since we don't want a huge list of front sprites
        bmp_path = GameData::Species.icon_filename(prize[:species])
        icon_bmp = AnimatedBitmap.new(bmp_path) if pbResolveBitmap(bmp_path)
      elsif prize[:type] == :item
        name = GameData::Item.get(prize[:item]).name
        name = _INTL("{1}x {2}", prize[:amount], name) if prize[:amount] && prize[:amount] > 1
        bmp_path = GameData::Item.icon_filename(prize[:item])
        icon_bmp = AnimatedBitmap.new(bmp_path) if pbResolveBitmap(bmp_path)
      end
      
      # Removed custom text spacing tag so the text aligns vertically with the rest of the list
      
      @prize_data.push({
        pct: pct,
        name: name,
        icon_bmp: icon_bmp,
        is_main: prize[:is_main_prize]
      })
    end
    
    # Sort from rarest to most common, but force Main Prizes to the top
    @prize_data.sort! do |a, b|
      if a[:is_main] != b[:is_main]
        a[:is_main] ? -1 : 1
      else
        a[:pct] <=> b[:pct]
      end
    end
  end
  
  def pbCreateList
    @sprites["list_window"] = Window_CommandPokemonEx.newEmpty(0, 48, Graphics.width, Graphics.height - 48, @viewport)
    
    commands = []
    @prize_data.each do |data|
      # Format percentage to 2 decimal places max
      pct_text = sprintf("%.2f%%", data[:pct])
      
      # We pad the text to give room for the icon, but not too much so it stays centered
      # The icon is at x=70, so we need a healthy padding to start past x=110.
      commands.push("                       " + data[:name] + " (" + pct_text + ")")
    end
    
    @sprites["list_window"].commands = commands
    @sprites["list_window"].index = 0
    @sprites["list_window"].windowskin = nil # Invisible borders
    
    # We will draw the icons dynamically inside the update loop based on the visible area
    @sprites["icons"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["icons"].z = 100
  end

  def pbDrawIcons
    @sprites["icons"].bitmap.clear
    window = @sprites["list_window"]
    return if !window || window.disposed?
    
    # The Window_Command limits viewable items. We only draw what's within the top/bottom bounds.
    visible_start = window.top_item
    visible_end = [visible_start + window.page_item_max - 1, @prize_data.length - 1].min
    
    (visible_start..visible_end).each do |i|
      data = @prize_data[i]
      next if !data[:icon_bmp]
      
      # Calculate local y position relative to the window scroll
      item_rect = window.itemRect(i)
      
      # Item rect Y is relative to the window's internal content.
      # We just need to know its screen position.
      y_pos = window.y + 16 + (i - visible_start) * 32
      
      # For AnimatedBitmap, we only want the first frame if it's a sprite sheet.
      # Usually, width is 64 for icons. If it's longer (e.g., 128), it's 2 frames.
      actual_bitmap = data[:icon_bmp].bitmap
      icon_h = actual_bitmap.height
      # Assume square frames (e.g., 64x64) or fallback to height. The total width defines frame count.
      icon_w = icon_h
      
      total_frames = actual_bitmap.width / icon_w
      total_frames = 1 if total_frames < 1
      
      current_frame = @anim_frame % total_frames
      
      src_rect = Rect.new(current_frame * icon_w, 0, icon_w, icon_h)
      
      dest_size = 40 # Scale down the sprites so they fit the rows neatly
      
      # Offset the icon further DOWN by adding more to the Y coordinate
      # to perfectly center it against the text string.
      dest_rect = Rect.new(70, y_pos - (dest_size / 2) + 12, dest_size, dest_size)
      
      @sprites["icons"].bitmap.stretch_blt(dest_rect, actual_bitmap, src_rect)
      
      if data[:is_main] && @star_bmp
        star_w = @star_bmp.width
        star_h = @star_bmp.height
        @sprites["icons"].bitmap.blt(142, y_pos - (star_h / 2) + 14, @star_bmp, Rect.new(0, 0, star_w, star_h))
      end
    end
  end

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
    
    @anim_timer += 1
    if @anim_timer >= 12 # Adjust animation speed here (lower is faster)
      @anim_timer = 0
      @anim_frame += 1
    end
    
    pbDrawIcons
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites)
    
    # Dispose bitmaps properly
    @prize_data.each do |data|
      data[:icon_bmp].dispose if data[:icon_bmp] && !data[:icon_bmp].disposed?
    end
    
    @star_bmp.dispose if @star_bmp && !@star_bmp.disposed?
    
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end

class GachaDetails_Screen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen(banner_id)
    @scene.pbStartScene(banner_id)
    loop do
      Graphics.update
      Input.update
      @scene.pbUpdate
      if Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || Input.trigger?(Input::ACTION)
        pbPlayCancelSE rescue nil
        break
      end
    end
    @scene.pbEndScene
  end
end
