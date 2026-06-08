#-----------------------------------------------------------------------------
# Main reward UI code
#-----------------------------------------------------------------------------
class RewardItemUI
  ITEMS_PER_ROW  = 5
  GRID_SPACING_X = 90
  GRID_SPACING_Y = 90

  REROLL_TEXT_SPACE = 128

  def initialize
    @viewport      = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z    = 99_999
    @sel_idx       = 0
    @reroll_count  = 0
    @item_pool     = []
    @item_rarities = []
    @sprites       = {}
    @sprites["bg"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["bg"].bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0, 160))
    @sprites["overlay_top"] = BitmapSprite.new(Graphics.width, Graphics.height / 2, @viewport)
    pbSetSmallFont(@sprites["overlay_top"].bitmap)
    @sprites["textbox"] = Sprite.new(@viewport)
    @sprites["textbox"].bitmap = RPG::Cache.load_bitmap("Graphics/UI/Rewards/", "overlay_desc")
    @sprites["textbox"].x = Graphics.width / 2
    @sprites["textbox"].y = Graphics.height - 4
    @sprites["textbox"].ox = @sprites["textbox"].bitmap.width / 2
    @sprites["textbox"].oy = @sprites["textbox"].bitmap.height
    @sprites["overlay_btm"] = BitmapSprite.new(Graphics.width, Graphics.height / 2, @viewport)
    @sprites["overlay_btm"].y += Graphics.height / 2
    pbSetSmallFont(@sprites["overlay_btm"].bitmap)
    @sprites["sel"] = SelectorSprite.new(@viewport, 4)
    @sprites["sel"].filename = "Graphics/UI/Rewards/overlay_select"
    @sprites["sel"].visible = false
    total_w = 0
    $player.party.each_with_index do |pkmn, i|
      @sprites["pkmn_#{i}"] = PokemonIconSprite.new(pkmn, @viewport)
      @sprites["pkmn_#{i}"].x = 64 * i
      @sprites["pkmn_#{i}"].y += 4
      total_w += @sprites["pkmn_#{i}"].src_rect.width
    end
    @sprites.each do |key, sprite|
      next if !key.to_s.start_with?("pkmn_")
      sprite.x += (Graphics.width - REROLL_TEXT_SPACE - total_w) / 2
    end
    start_scene
  end

  def update
    pbUpdateSpriteHash(@sprites)
  end

  def dispose
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  def start_scene
    refresh_screen
    fade_screen
    @sprites["sel"].visible = true
  end

  def end_scene
    fade_screen(false)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  def fade_screen(fade_in = true)
    @sprites.each_value { |sprite| sprite.opacity = 0 } if fade_in
    time_start = System.uptime
    duration = 0.75
    loop do
      Graphics.update
      update
      timer = System.uptime - time_start
      timer = duration if timer >= duration
      factor = timer / duration
      @sprites.each_value do |sprite|
        sprite.opacity = 255 * ((fade_in) ? factor : 1 - factor)
      end
      break if timer >= duration
    end
  end

  def fade_items(fade_in = true)
    if fade_in
      @sprites.each do |key, sprite|
        next if !key.to_s.start_with?("item_")
        sprite.opacity = 0
      end
    end
    time_start = System.uptime
    duration = 0.4
    loop do
      Graphics.update
      update
      timer = System.uptime - time_start
      timer = duration if timer >= duration
      factor = timer / duration
      @sprites.each do |key, sprite|
        next if !key.to_s.start_with?("item_")
        sprite.opacity = 255 * ((fade_in) ? factor : 1 - factor)
      end
      break if timer >= duration
    end
    pbWait(0.4) { update } if !fade_in
  end

  def toggle_textbox(show = false)
    @sprites["sel"].visible = show
    @sprites["textbox"].visible = show
    @sprites["overlay_btm"].visible = show
    update
  end

  def refresh_screen
    refresh_item_pool
    refresh_item_sprites
    refresh_selected
  end

  def refresh_item_sprites
    @sprites.each { |key, sprite| sprite.dispose if key.to_s.start_with?("item_") }
    @sprites.delete_if { |key, sprite| sprite.disposed? }
    return if @item_pool.empty?
    num_rows = (@item_pool.size.to_f / ITEMS_PER_ROW).ceil
    total_grid_height = (num_rows * GRID_SPACING_Y) - 16
    textbox_top_y = @sprites["textbox"].y - @sprites["textbox"].oy
    available_height = textbox_top_y - 68
    start_y = 68 + ((available_height - total_grid_height) / 2)
    start_y = [start_y, 0].max
    current_row_start_x = 0
    @item_pool.each_with_index do |item, i|
      row = i / ITEMS_PER_ROW
      col = i % ITEMS_PER_ROW
      rarity = @item_rarities[i] || :common
      bmp = RPG::Cache.load_bitmap("Graphics/UI/Rewards/", "overlay_item_#{rarity}")
      if col == 0
        remaining_items = @item_pool.size - i
        items_in_this_row = [remaining_items, ITEMS_PER_ROW].min
        row_width = ((items_in_this_row - 1) * GRID_SPACING_X) + bmp.width
        current_row_start_x = (Graphics.width - row_width) / 2
      end
      key = "item_#{i}"
      @sprites[key] = Sprite.new(@viewport)
      @sprites[key].bitmap = Bitmap.new(bmp.width, bmp.height)
      @sprites[key].bitmap.blt(0, 0, bmp, bmp.rect)
      @sprites[key].x = current_row_start_x + (col * GRID_SPACING_X)
      @sprites[key].y = start_y + (row * GRID_SPACING_Y)
      item_bmp = RPG::Cache.load_bitmap("", GameData::Item.icon_filename(item))
      offset = (bmp.width - item_bmp.width) / 2
      @sprites[key].bitmap.blt(offset, offset, item_bmp, item_bmp.rect)
      item_bmp.dispose
      bmp.dispose
    end
    overlay = @sprites["overlay_top"].bitmap
    overlay.clear
    pbDrawTextPositions(overlay, [
      [_INTL("Reroll: Z ({1} BP)", reroll_cost), Graphics.width - REROLL_TEXT_SPACE, 12, :left, Color.white, Color.new(0, 0, 0), true],
      [_INTL("{1} BP left", $player.battle_points), Graphics.width - REROLL_TEXT_SPACE, 38, :left, Color.white, Color.new(0, 0, 0), true],
    ])
  end

  def refresh_selected
    return if !@sprites["item_#{@sel_idx}"]
    @sprites["sel"].target(@sprites["item_#{@sel_idx}"])
    overlay = @sprites["overlay_btm"].bitmap
    overlay.clear
    item_data = GameData::Item.get(@item_pool[@sel_idx])
    rarity_id = @item_rarities[@sel_idx] || :common
    rarity_data = GameData::RewardPool::RARITY_DATA[rarity_id]
    y_pos = @sprites["textbox"].y - @sprites["textbox"].height + 16 - (Graphics.height / 2) - 8
    pbDrawTextPositions(overlay, [
      [item_data.name, 136, y_pos, :center, Color.white, Color.new(0, 0, 0, 80)],
      [rarity_data[:name], 416, y_pos, :center, rarity_data[:color], Color.new(0, 0, 0, 80)]
    ])
    x_pos = ((Graphics.width - @sprites["textbox"].width) / 2) + 26
    y_pos += 32
    drawFormattedTextEx(overlay, x_pos, y_pos, 452, item_data.description,
      MessageConfig::DARK_TEXT_MAIN_COLOR, MessageConfig::DARK_TEXT_SHADOW_COLOR, 26)
  end

  def refresh_item_pool
    @item_pool.clear
    @item_rarities.clear
    var_count = $game_variables[REWARD_COUNT_VARIABLE] rescue 5
    count = [var_count, 5].max
    generated_rewards = GameData::RewardPool.generate(count)
    if generated_rewards && !generated_rewards.empty?
      @item_pool, @item_rarities = generated_rewards.transpose
    else
      @item_pool = [:POTION] * count
      @item_rarities = [:common] * count
    end
  end

  def reroll_cost
    var_cost = $game_variables[REWARD_REROLL_COST_VARIABLE] rescue 1
    cost = [var_cost, 1].max
    return cost + @reroll_count
  end

  def main
    loop do
      Graphics.update
      Input.update
      update
      old_idx = @sel_idx
      if Input.trigger?(Input::USE)
        selected_item = @item_pool[@sel_idx]
        item_data = GameData::Item.get(selected_item)
        toggle_textbox
        if pbConfirmMessage(_INTL("Do you want to receive the {1}?", item_data.name)) { update }
          pbReceiveItem(item_data.id)
          end_scene
          break
        end
        toggle_textbox(true)
      elsif Input.trigger?(Input::ACTION)
        toggle_textbox
        cost = reroll_cost
        if $player.battle_points < cost
          pbMessage(_INTL("You don't have enough BP to reroll your rewards.")) { update }
        elsif pbConfirmMessage(_INTL("Do you want to reroll your rewards for {1} BP?", cost)) { update }
          $player.battle_points -= cost
          @reroll_count += 1
          fade_items(false)
          refresh_screen
          @sprites.each do |key, sprite|
            next if !key.to_s.start_with?("item_")
            sprite.opacity = 0
          end
          fade_items(true)
        end
        toggle_textbox(true)
      elsif Input.trigger?(Input::BACK) && CAN_CANCEL_REWARD_SCREEN
        toggle_textbox
        if pbConfirmMessage(_INTL("Do you want to proceed without selecting any reward?")) { update }
          end_scene
          break
        end
        toggle_textbox(true)
      elsif Input.trigger?(Input::UP)
        @sel_idx -= ITEMS_PER_ROW if @sel_idx >= ITEMS_PER_ROW
        @sel_idx = 0 if @sel_idx < 0
      elsif Input.trigger?(Input::DOWN)
        @sel_idx += ITEMS_PER_ROW if @sel_idx < @item_pool.size - ITEMS_PER_ROW + 1
        @sel_idx = @item_pool.size - 1 if @sel_idx >= @item_pool.size
      elsif Input.trigger?(Input::LEFT)
        @sel_idx -= 1 if @sel_idx % ITEMS_PER_ROW > 0
      elsif Input.trigger?(Input::RIGHT)
        @sel_idx += 1 if @sel_idx % ITEMS_PER_ROW < ITEMS_PER_ROW - 1 && @sel_idx < @item_pool.size - 1
      end
      if @sel_idx != old_idx
        pbPlayCursorSE
        refresh_selected
      end
    end
  end
end

def pbShowRewardsScreen
  scene = RewardItemUI.new
  scene.main
end
