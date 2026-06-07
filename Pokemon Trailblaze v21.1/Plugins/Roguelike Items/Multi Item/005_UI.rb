#-----------------------------------------------------------------------------
# Adding multiple items to the Summary screen
#-----------------------------------------------------------------------------
=begin
class PokemonSummary_Scene
  alias __roguelike__drawPage drawPage unless method_defined?(:__roguelike__drawPage)
  def drawPage(*args)
    __roguelike__drawPage(*args)
    return if @pokemon.egg?
    @item_idx = -1 if !@item_idx
    @item_overlay_bmp ||= RPG::Cache.load_bitmap("Graphics/UI/Summary/", "overlay_item_names")
    @item_desc_bmp ||= RPG::Cache.load_bitmap("Graphics/UI/Summary/", "overlay_item_desc")
    @item_selarrow ||= RPG::Cache.load_bitmap("Graphics/UI/", "sel_arrow")
    @sprites["itemicon"].item = nil
    overlay = @sprites["overlay"].bitmap
    overlay.fill_rect(0, 124, 208, 260, Color.new(0, 0, 0, 0))
    bar_height = (@item_overlay_bmp.height - 6) / 2
    rect = Rect.new(0, 0, @item_overlay_bmp.width, bar_height)
    rect.y = 0
    rect.height = 6
    pbSetSmallFont(overlay)
    item_counts = @pokemon.items.each_with_object(Hash.new(0)) { |item, counts| counts[item] += 1 }
    unique_items = item_counts.keys
    if @item_idx >= 0 && @pokemon.item_count > 0
      bg_y = Graphics.height - (bar_height * (unique_items.length + 1)) - 6
      overlay.blt(0, bg_y, @item_overlay_bmp, rect)
      rect.y = 6
      rect.height = bar_height
      bg_y += 6
      overlay.blt(0, bg_y, @item_overlay_bmp, rect)
      text_y = bg_y + 4
      pbDrawTextPositions(overlay, [
        [_INTL("BACK: Hide Details"), 18, text_y, :left, Color.white, BLACK_TEXT_BASE]
      ])
      rect.y = bar_height + 6
      unique_items.each_with_index do |item, i|
        count = item_counts[item]
        item_bg_y = bg_y + (bar_height * (i + 1))
        overlay.blt(0, item_bg_y, @item_overlay_bmp, rect)
        item_text_y = item_bg_y + 4
        item_name = GameData::Item.get(item).name
        display_text = (count > 1) ? _INTL("{1} x{2}", item_name, count) : item_name
        pbDrawTextPositions(overlay, [
          [display_text, 18, item_text_y, :left, BLACK_TEXT_BASE, BLACK_TEXT_SHADOW]
        ])
        if i == @item_idx
          x = @item_overlay_bmp.width
          y = item_text_y - @item_desc_bmp.height + bar_height - 4
          overlay.blt(x, y, @item_desc_bmp, @item_desc_bmp.rect)
          overlay.blt(4, item_text_y - 8, @item_selarrow, @item_selarrow.rect)
          item_icon = RPG::Cache.load_bitmap("", GameData::Item.icon_filename(item))
          overlay.blt(x + 52 - (item_icon.width / 2), y + 34 - (item_icon.height / 2), item_icon, item_icon.rect)
          item_icon.dispose
          pbSetSystemFont(overlay)
          pbDrawTextPositions(overlay, [
            [item_name, x + 91, y + 35, :left,
             MessageConfig::LIGHT_TEXT_MAIN_COLOR,
             MessageConfig::LIGHT_TEXT_SHADOW_COLOR]
          ])
          pbSetSmallFont(overlay)
          drawFormattedTextEx(overlay, x + 26, y + 70, 266, GameData::Item.get(item).description, BLACK_TEXT_BASE, BLACK_TEXT_SHADOW, 26)
        end
      end
    else
      bg_y = Graphics.height - bar_height - 6
      overlay.blt(0, bg_y, @item_overlay_bmp, rect)
      rect.y = 6
      rect.height = bar_height
      bg_y += 6
      overlay.blt(0, bg_y, @item_overlay_bmp, rect)
      text_y = bg_y + 4
      item_text = if @pokemon.items_empty?
                    _INTL("No Held Items")
                  elsif @page == 4
                    _INTL("C: Move Options")
                  else
                    _INTL("C: Item Options")
                  end
      pbDrawTextPositions(overlay, [
        [item_text, 16, text_y, :left, Color.white, BLACK_TEXT_BASE]
      ])
      unless @pokemon.items_empty?
        placeholder_icon = GameData::Item.icon_filename(nil)
        bmp = RPG::Cache.load_bitmap("", placeholder_icon)
        icon_w = bmp.width
        icon_h = bmp.height
        bmp.dispose
        offset = 0
        spacing = icon_w
        num_unique_items = unique_items.length
        if (icon_w * num_unique_items) <= 208
          offset = (208 - (icon_w * num_unique_items)) / 2
        else
          offset = 0
          spacing = (208.to_f - icon_w) / (num_unique_items - 1) if num_unique_items > 1
        end
        icon_y = bg_y - (12 + icon_h)
        unique_items.each_with_index do |item, i|
          bmp = RPG::Cache.load_bitmap("", GameData::Item.icon_filename(item))
          icon_x = (offset + (i * spacing)).round
          overlay.blt(icon_x, icon_y, bmp, bmp.rect)
          bmp.dispose
        end
        unique_items.each_with_index do |item, i|
          count = item_counts[item]
          next if count <= 1
          icon_x = (offset + (i * spacing)).round
          qty_text = "x#{count}"
          text_x = icon_x + icon_w - 2
          text_y = icon_y + icon_h - 14
          pbDrawTextPositions(overlay, [
            [qty_text, text_x, text_y, :right, Color.white, BLACK_TEXT_BASE, true]
          ])
        end
      end
    end
    pbSetSystemFont(overlay)
  end

  def show_item_details
    @item_idx = 0
    drawPage(@page)
    loop do
      Graphics.update
      Input.update
      pbUpdate
      old_idx = @item_idx
      if Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::UP)
        @item_idx -= 1
        @item_idx = 0 if @item_idx < 0
      elsif Input.trigger?(Input::DOWN)
        @item_idx += 1
        @item_idx = @pokemon.items.length - 1 if @item_idx >= @pokemon.items.length
      end
      if old_idx != @item_idx
        pbPlayCursorSE
        drawPage(@page)
      end
    end
    @item_idx = -1
  end

  alias __roguelike__pbEndScene pbEndScene unless method_defined?(:__roguelike__pbEndScene)
  def pbEndScene(*args)
    __roguelike__pbEndScene(*args)
    @item_overlay_bmp&.dispose
    @item_overlay_bmp = nil
    @item_desc_bmp&.dispose
    @item_desc_bmp = nil
    @item_selarrow&.dispose
    @item_selarrow = nil
  end

  def pbOptions
    dorefresh = false
    commands = []
    cmdViewItems  = -1
    cmdGiveItem   = -1
    cmdTakeItem   = -1
    cmdNickname   = -1
    cmdPokedex    = -1
    cmdMark       = -1
    cmdCheckMoves = -1
    cmdLearnMoves = -1
    cmdForgetMove = -1
    cmdTeachTMs   = -1
    case @page
    when 4
      commands[cmdCheckMoves = commands.length] = _INTL("Check Moves") if !@pokemon.moves.empty?
      commands[cmdLearnMoves = commands.length] = _INTL("Remember Moves") if @pokemon.can_relearn_move?
      commands[cmdForgetMove = commands.length] = _INTL("Forget Moves") if @pokemon.moves.length > 1
      commands[cmdTeachTMs   = commands.length] = _INTL("Use TM's")
    else
      if !@pokemon.egg?
        commands[cmdViewItems = commands.length] = _INTL("View Items") if @pokemon.hasItem?
        commands[cmdGiveItem  = commands.length] = _INTL("Give item")
        commands[cmdTakeItem  = commands.length] = _INTL("Take item") if @pokemon.hasItem?
        commands[cmdNickname  = commands.length] = _INTL("Nickname") if !@pokemon.foreign?
        commands[cmdPokedex   = commands.length] = _INTL("View Pokédex") if $player.has_pokedex
      end
      commands[cmdMark = commands.length] = _INTL("Mark")
    end
    commands[commands.length] = _INTL("Cancel")
    command = pbShowCommands(commands)
    if cmdViewItems >= 0 && command == cmdViewItems
      show_item_details
      dorefresh = true
    elsif cmdGiveItem >= 0 && command == cmdGiveItem
      item = nil
      pbFadeOutIn {
        scene = PokemonBag_Scene.new
        screen = PokemonBagScreen.new(scene, $bag)
        item = screen.pbChooseItemScreen(proc { |itm| GameData::Item.get(itm).can_hold? })
      }
      if item
        dorefresh = pbGiveItemToPokemon(item, @pokemon, self, @partyindex)
      end
    elsif cmdTakeItem >= 0 && command == cmdTakeItem
      dorefresh = pbTakeItemFromPokemon(@pokemon, self)
    elsif cmdNickname >= 0 && command == cmdNickname
      nickname = pbEnterPokemonName(_INTL("{1}'s nickname?", @pokemon.name), 0, Pokemon::MAX_NAME_SIZE, "", @pokemon, true)
      @pokemon.name = nickname
      dorefresh = true
    elsif cmdPokedex >= 0 && command == cmdPokedex
      $player.pokedex.register_last_seen(@pokemon)
      pbFadeOutIn {
        scene = PokemonPokedexInfo_Scene.new
        screen = PokemonPokedexInfoScreen.new(scene)
        screen.pbStartSceneSingle(@pokemon.species)
      }
      dorefresh = true
    elsif cmdMark >= 0 && command == cmdMark
      dorefresh = pbMarking(@pokemon)
    elsif cmdCheckMoves >= 0 && command == cmdCheckMoves
      pbPlayDecisionSE
      pbMoveSelection
      dorefresh = true
    elsif cmdLearnMoves >= 0 && command == cmdLearnMoves
      pbRelearnMoveScreen(@pokemon)
      dorefresh = true
    elsif cmdForgetMove >= 0 && command == cmdForgetMove
      move_index = pbForgetMove(@pokemon, nil)
      if move_index >= 0
        old_move_name = @pokemon.moves[move_index].name
        pbMessage(_INTL("{1} forgot how to use {2}.", @pokemon.name, old_move_name))
        @pokemon.forget_move_at_index(move_index)
        dorefresh = true
      end
    elsif cmdTeachTMs >= 0 && command == cmdTeachTMs
      item = nil
      pbFadeOutIn {
        scene  = PokemonBag_Scene.new
        screen = PokemonBagScreen.new(scene, $bag)
        item = screen.pbChooseItemScreen(Proc.new{ |itm|
          move = GameData::Item.get(itm).move
          next false if !move || @pokemon.hasMove?(move) || !@pokemon.compatible_with_move?(move)
          next true
        })
      }
      if item
        pbUseItemOnPokemon(item, @pokemon, self)
        dorefresh = true
      end
    end
    return dorefresh
  end

=begin
  alias __roguelike__pbChangePokemon pbChangePokemon unless method_defined?(:__roguelike__pbChangePokemon)
  def pbChangePokemon(*args)
    __roguelike__pbChangePokemon(*args)
    @show_items = false
  end

  alias __roguelike__pbUpdate pbUpdate unless method_defined?(:__roguelike__pbUpdate)
  def pbUpdate(*args)
    __roguelike__pbUpdate(*args)
    return if !Input.trigger?(Input::ACTION)
    if !@pokemon.items_empty?
      pbPlayCursorSE
      @show_items = !@show_items
      drawPage(@page)
    end
    Input.update
  end
 =end
end
=end
=begin
#-------------------------------------------------------------------------------
# Giving multiple items
#-------------------------------------------------------------------------------
def pbGiveItemToPokemon(item, pkmn, scene, pkmnid = 0)
  newitemname = GameData::Item.get(item).portion_name
  if pkmn.egg?
    scene.pbDisplay(_INTL("Eggs can't hold items."))
    return false
  elsif pkmn.items_full?
    scene.pbDisplay(_INTL("{1} cannot hold more items.", pkmn.name) + "\1")
    return false if !scene.pbConfirm(_INTL("Would you like to replace an existing held item?"))
    sel_item = pbSelectItemScene(pkmn, scene, _INTL("Replace which item?"))
    return false if !sel_item
    olditemname = GameData::Item.get(sel_item).portion_name
    $bag.remove(item)
    if !$bag.add(sel_item)
      raise _INTL("Couldn't re-store deleted item in Bag somehow") if !$bag.add(item)
      scene.pbDisplay(_INTL("The Bag is full. The Pokémon's item could not be removed."))
      return false
    elsif GameData::Item.get(sel_item).is_mail?
      scene.pbDisplay(_INTL("{1}'s mail must be removed before replacing it with another item.", pkmn.name))
      return false if !pbRemoveMailScene(sel_item, pkmn, scene)
    else
      pkmn.remove_item(sel_item)
    end
    if GameData::Item.get(item).is_mail?
      pbWriteMail(item, pkmn, pkmnid, scene)
      if !$bag.add(item)
        raise _INTL("Couldn't re-store deleted item in Bag somehow")
      end
    end
    pkmn.item = item
    scene.pbDisplay(_INTL("Took the {1} from {2} and gave it the {3}.", olditemname, pkmn.name, newitemname))
    return true
  elsif !GameData::Item.get(item).is_mail? || pbWriteMail(item, pkmn, pkmnid, scene)
    $bag.remove(item)
    pkmn.item = item
    scene.pbDisplay(_INTL("{1} is now holding the {2}.", pkmn.name, newitemname))
    return true
  end
  return false
end
=end
# UI taken care off in it's own equiptment page, so it's deprecated in here.
#-------------------------------------------------------------------------------
# Helper to determine an item's category
# To define an item, simply give it the flag "Defensive, Offensive or Utility
# The code is not made to handle items having multiple categories so be careful while giving them,
# Or mod pbGiveItemToPokemon to allow selecting multiple categories.
# Also, for balance of my own game, all berries are considered utility items. You can change that removing the "|| item_data.is_berry?" for the utility check
#-------------------------------------------------------------------------------
def pbItemCategory(item)
  item_data = GameData::Item.get(item)
  return :Defensive if item_data.has_flag?("Defensive")
  return :Offensive if item_data.has_flag?("Offensive")
  return :Utility   if item_data.has_flag?("Utility") || item_data.is_berry?
  return :Extra
end
#-------------------------------------------------------------------------------
# Giving multiple items (with category restriction)
#-------------------------------------------------------------------------------
def pbGiveItemToPokemon(item, pkmn, scene, pkmnid = 0)
  newitemdata = GameData::Item.get(item)
  newitemname = newitemdata.portion_name
  newcat      = pbItemCategory(item)

  if pkmn.egg?
    scene.pbDisplay(_INTL("Eggs can't hold items."))
    return false
  end

  # --- Category restriction check --------------------------------------------
  samecat_item = pkmn.items.find { |i| pbItemCategory(i) == newcat }
  if samecat_item
    samecat_name = GameData::Item.get(samecat_item).portion_name
    msg = _INTL("{1} is already holding the {2}. Replace it?",
                pkmn.name, samecat_name)
    return false if !scene.pbConfirm(msg)
    pkmn.remove_item(samecat_item)
    $bag.add(samecat_item)
  elsif pkmn.items_full?
    scene.pbDisplay(_INTL("{1} cannot hold more items.", pkmn.name) + "\1")
    return false if !scene.pbConfirm(_INTL("Would you like to replace an existing held item?"))
    sel_item = pbSelectItemScene(pkmn, scene, _INTL("Replace which item?"))
    return false if !sel_item
    olditemname = GameData::Item.get(sel_item).portion_name
    $bag.remove(item)
    if !$bag.add(sel_item)
      raise _INTL("Couldn't re-store deleted item in Bag somehow") if !$bag.add(item)
      scene.pbDisplay(_INTL("The Bag is full. The Pokémon's item could not be removed."))
      return false
    elsif GameData::Item.get(sel_item).is_mail?
      scene.pbDisplay(_INTL("{1}'s mail must be removed before replacing it with another item.", pkmn.name))
      return false if !pbRemoveMailScene(sel_item, pkmn, scene)
    else
      pkmn.remove_item(sel_item)
    end
    scene.pbDisplay(_INTL("Took the {1} from {2} and gave it the {3}.", olditemname, pkmn.name, newitemname))
  end
  # ---------------------------------------------------------------------------

  # Handle mail or standard give
  if !newitemdata.is_mail? || pbWriteMail(item, pkmn, pkmnid, scene)
    $bag.remove(item)
    pkmn.item = item
    scene.pbDisplay(_INTL("{1} is now holding the {2}.", pkmn.name, newitemname))
    return true
  end
  return false
end
#-------------------------------------------------------------------------------
# Taking multiple items
#-------------------------------------------------------------------------------
def pbTakeItemFromPokemon(pkmn, scene)
  if pkmn.items_empty?
    scene.pbDisplay(_INTL("{1} isn't holding anything.", pkmn.name))
    return false
  end
  sel_item = pbSelectItemScene(pkmn, scene, _INTL("Take which item?"))
  return false if !sel_item
  if !$bag.can_add?(sel_item)
    scene.pbDisplay(_INTL("The Bag is full. The Pokémon's item could not be removed."))
  elsif GameData::Item.get(sel_item).is_mail?
    return pbRemoveMailScene(sel_item, pkmn, scene)
  else
    pkmn.remove_item(sel_item)
    $bag.add(sel_item)
    scene.pbDisplay(_INTL("Received the {1} from {2}.", GameData::Item.get(sel_item).portion_name, pkmn.name))
    return true
  end
  return false
end

#-------------------------------------------------------------------------------
# Utility methods for selecting from multiple items and mails
#-------------------------------------------------------------------------------
def pbSelectItemScene(pkmn, scene, message = nil)
  selected_idx = -1
  if pkmn.item_count == 1
    selected_idx = 0
  else
    commands = []
    pkmn.each_item { |i| commands.push(i.name) }
    commands.push(_INTL("Cancel"))
    if scene.is_a?(PokemonSummary_Scene)
      selected_idx = scene.pbShowCommands(commands)
    else
      selected_idx = scene.pbShowCommands(message || _INTL("Select an item..."), commands)
    end
  end
  return nil if selected_idx == -1 || selected_idx == pkmn.item_count
  return pkmn.items[selected_idx]
end

def pbRemoveMailScene(item, pkmn, scene)
  if scene.pbConfirm(_INTL("Save the removed mail in your PC?"))
    if !pbMoveToMailbox(pkmn)
      scene.pbDisplay(_INTL("Your PC's Mailbox is full."))
      return false
    end
    scene.pbDisplay(_INTL("The mail was saved in your PC."))
    pkmn.remove_item(item)
    return true
  elsif scene.pbConfirm(_INTL("If the mail is removed, its message will be lost. OK?"))
    $bag.add(item)
    scene.pbDisplay(_INTL("Received the {1} from {2}.", pkmn.item.portion_name, pkmn.name))
    pkmn.remove_item(item)
    pkmn.mail = nil
    return true
  end
  return false
end

#-------------------------------------------------------------------------------
# Party menu handlers to check mail/move multiple items
#-------------------------------------------------------------------------------
MenuHandlers.add(:party_menu, :mail, {
  "name"      => _INTL("Read Mail"),
  "order"     => 40,
  "condition" => proc { |screen, party, party_idx| next !party[party_idx].egg? && party[party_idx].mail },
  "effect"    => proc { |screen, party, party_idx|
    pkmn = party[party_idx]
    pbFadeOutIn do
      pbDisplayMail(pkmn.mail, pkmn)
      screen.scene.pbSetHelpText((party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
    end
  }
})

MenuHandlers.add(:party_menu, :item, {
  "name"      => _INTL("Items"),
  "order"     => 50,
  "condition" => proc { |screen, party, party_idx| next !party[party_idx].egg? },
  "effect"    => proc { |screen, party, party_idx|
    command_list = []
    commands = []
    MenuHandlers.each_available(:party_menu_item, screen, party, party_idx) do |option, hash, name|
      command_list.push(name)
      commands.push(hash)
    end
    command_list.push(_INTL("Cancel"))
    item_str = party[party_idx].items.map { |i| GameData::Item.get(i).name }.join(", ")
    msg = (party[party_idx].hasItem?) ? _INTL("Items: {1}", item_str) : _INTL("No held items")
    choice = screen.scene.pbShowCommands(msg, command_list)
    next if choice < 0 || choice >= commands.length
    commands[choice]["effect"].call(screen, party, party_idx)
  }
})
=begin
MenuHandlers.add(:party_menu_item, :move, {
  "name"      => _INTL("Move"),
  "order"     => 40,
  "condition" => proc { |screen, party, party_idx| next party[party_idx].hasItem? },
  "effect"    => proc { |screen, party, party_idx|
    pkmn = party[party_idx]
    sel_item = pbSelectItemScene(pkmn, screen.scene, _INTL("Move which item?"))
    next if !sel_item
    item_data = GameData::Item.get(sel_item)
    itemname = item_data.name
    portionitemname = item_data.portion_name
    screen.scene.pbSetHelpText(_INTL("Move {1} to where?", itemname))
    old_party_idx = party_idx
    moved = false
    loop do
      screen.scene.pbPreSelect(old_party_idx)
      party_idx = screen.scene.pbChoosePokemon(true, party_idx)
      break if party_idx < 0
      newpkmn = party[party_idx]
      break if party_idx == old_party_idx
      if newpkmn.egg?
        screen.pbDisplay(_INTL("Eggs can't hold items."))
        next
      elsif !newpkmn.items_full?
        newpkmn.item = sel_item
        pkmn.remove_item(sel_item)
        screen.scene.pbClearSwitching
        screen.pbRefresh
        screen.pbDisplay(_INTL("{1} was given the {2} to hold.", newpkmn.name, portionitemname))
        moved = true
        break
      elsif GameData::Item.get(sel_item).is_mail?
        screen.pbDisplay(_INTL("{1}'s mail must be removed before giving it an item.", newpkmn.name))
        next
      end
      new_item = pbSelectItemScene(newpkmn, screen.scene, _INTL("Replace which item?"))
      next if !new_item
      newitemname = GameData::Item.get(new_item).portion_name
      pkmn.remove_item(sel_item)
      newpkmn.remove_item(new_item)
      newpkmn.item = sel_item
      pkmn.item = new_item
      screen.scene.pbClearSwitching
      screen.pbRefresh
      screen.pbDisplay(_INTL("{1} was given the {2} to hold.", newpkmn.name, portionitemname) + "\1")
      screen.pbDisplay(_INTL("{1} was given the {2} to hold.", pkmn.name, newitemname))
      moved = true
      break
    end
    screen.scene.pbSelect(old_party_idx) if !moved
  }
})
=end
MenuHandlers.add(:party_menu_item, :move, {
  "name"      => _INTL("Move"),
  "order"     => 40,
  "condition" => proc { |screen, party, party_idx| next party[party_idx].hasItem? },
  "effect"    => proc { |screen, party, party_idx|
    pkmn = party[party_idx]
    sel_item = pbSelectItemScene(pkmn, screen.scene, _INTL("Move which item?"))
    next if !sel_item

    item_data       = GameData::Item.get(sel_item)
    itemname        = item_data.name
    portionitemname = item_data.portion_name
    item_category   = pbItemCategory(sel_item)

    screen.scene.pbSetHelpText(_INTL("Move {1} to where?", itemname))
    old_party_idx = party_idx
    moved = false

    loop do
      screen.scene.pbPreSelect(old_party_idx)
      party_idx = screen.scene.pbChoosePokemon(true, party_idx)
      break if party_idx < 0
      newpkmn = party[party_idx]
      break if party_idx == old_party_idx

      # --- Category restriction check ----------------------------------------
      samecat_item = newpkmn.items.find { |i| pbItemCategory(i) == item_category }
      if samecat_item
        samecat_name = GameData::Item.get(samecat_item).portion_name
        msg = _INTL("{1} is already holding the {2}, which is a {3}-type item. Replace it?",
                    newpkmn.name, samecat_name, item_category.to_s.downcase)
        next if !screen.pbConfirm(msg)
        newpkmn.remove_item(samecat_item)
        $bag.add(samecat_item)
      end
      # ----------------------------------------------------------------------

      if newpkmn.egg?
        screen.pbDisplay(_INTL("Eggs can't hold items."))
        next
      elsif !newpkmn.items_full?
        newpkmn.item = sel_item
        pkmn.remove_item(sel_item)
        screen.scene.pbClearSwitching
        screen.pbRefresh
        screen.pbDisplay(_INTL("{1} was given the {2} to hold.", newpkmn.name, portionitemname))
        moved = true
        break
      elsif GameData::Item.get(sel_item).is_mail?
        screen.pbDisplay(_INTL("{1}'s mail must be removed before giving it an item.", newpkmn.name))
        next
      end

      # Default replacement logic (for non-category situations)
      new_item = pbSelectItemScene(newpkmn, screen.scene, _INTL("Replace which item?"))
      next if !new_item
      newitemname = GameData::Item.get(new_item).portion_name
      pkmn.remove_item(sel_item)
      newpkmn.remove_item(new_item)
      newpkmn.item = sel_item
      pkmn.item = new_item
      screen.scene.pbClearSwitching
      screen.pbRefresh
      screen.pbDisplay(_INTL("{1} was given the {2} to hold.", newpkmn.name, portionitemname) + "\1")
      screen.pbDisplay(_INTL("{1} was given the {2} to hold.", pkmn.name, newitemname))
      moved = true
      break
    end

    screen.scene.pbSelect(old_party_idx) if !moved
  }
})
#-------------------------------------------------------------------------------
# Held item icon appears for any item
#-------------------------------------------------------------------------------
=begin
class HeldItemIconSprite
  def item=(value)
    self.pokemon = @pokemon
  end

  def pokemon=(value)
    @pokemon = value
    @animbitmap&.dispose
    @animbitmap = nil
    if @pokemon.hasItem?
      @animbitmap = AnimatedBitmap.new("Graphics/UI/Party/icon_item")
      self.bitmap = @animbitmap.bitmap
    else
      self.bitmap = nil
    end
  end

  def update
    super
    return if !@animbitmap
    @animbitmap.update
    self.bitmap = @animbitmap.bitmap
  end
end
=end
#-------------------------------------------------------------------------------
# Set multiple items debug menu
#-------------------------------------------------------------------------------
MenuHandlers.add(:pokemon_debug_menu, :set_item, {
  "name"   => _INTL("Items..."),
  "parent" => :main,
  "effect" => proc { |pkmn, pkmnid, heldpoke, _, screen|
    cmd = 0
    commands = []
    if pkmn.items_full?
      commands.push(_INTL("Replace items"))
    else
      commands.push(_INTL("Give items"))
    end
    commands.push(_INTL("Remove items"))
    commands.push(_INTL("Cancel"))
    loop do
      item_str = pkmn.items.map { |i| GameData::Item.get(i).name }.join(", ")
      msg = (pkmn.hasItem?) ? _INTL("Items: {1}", item_str) : _INTL("No held items")
      cmd = screen.pbShowCommands(msg, commands, cmd)
      break if cmd < 0
      case cmd
      when 0
        item = pbChooseItemList
        next if !item
        if pkmn.items_full?
          i_commands = []
          pkmn.each_item { |i| i_commands.push(i.name) }
          i_cmd = screen.pbShowCommands(_INTL("Choose item to replace."), i_commands, 0)
          next if i_cmd < 0
          old_item = pkmn.items[i_cmd]
          pkmn.remove_item(old_item)
          pkmn.mail = nil if GameData::Item.get(old_item).is_mail?
        end
        pkmn.item = item
        pkmn.mail = Mail.new(item, _INTL("Text"), $player.name) if GameData::Item.get(item).is_mail?
        screen.pbRefreshSingle(pkmnid)
      when 1
        if pkmn.item_count == 0
          screen.pbDisplay(_INTL("There are no items to remove."))
        elsif pkmn.item_count == 1
          pkmn.item = nil
          pkmn.mail = nil
        else
          i_commands = []
          pkmn.each_item { |i| i_commands.push(i.name) }
          i_commands.insert(0, _INTL("Remove all Items"))
          i_cmd = screen.pbShowCommands(_INTL("Choose items to remove."), i_commands, 0)
          next if i_cmd < 0
          if i_cmd == 0
            pkmn.items.clear
            screen.pbDisplay(_INTL("All of {1}'s items were removed.", pkmn.name))
            break
          else
            item = pkmn.items[i_cmd - 1]
            pkmn.remove_item(item)
            pkmn.mail = nil if GameData::Item.get(item).is_mail?
          end
        end
        screen.pbRefreshSingle(pkmnid)
      else
        break
      end
    end
    next false
  }
})

MenuHandlers.add(:battle_pokemon_debug_menu, :set_item, {
  "name"   => _INTL("Items..."),
  "parent" => :main,
  "usage"  => :both,
  "effect" => proc { |pkmn, battler, battle|
    cmd = 0
    commands = []
    if pkmn.items_full?
      commands.push(_INTL("Replace items"))
    else
      commands.push(_INTL("Give items"))
    end
    commands.push(_INTL("Remove items"))
    commands.push(_INTL("Cancel"))
    loop do
      item_str = (battler || pkmn).items.map { |i| GameData::Item.get(i).name }.join(", ")
      msg = (!(battler || pkmn).items_full?) ? _INTL("Items: {1}", item_str) : _INTL("No held items")
      cmd = pbMessage("\\ts[]" + msg, commands, -1)
      break if cmd < 0
      case cmd
      when 0
        item = pbChooseItemList
        next if !item
        if (battler || pkmn).items_full?
          i_commands = []
          (battler || pkmn).each_item { |i| i_commands.push(i.name) }
          i_cmd = pbMessage("\\ts[]" + _INTL("Choose item to replace."), i_commands, -1)
          next if i_cmd < 0
          old_item = (battler || pkmn).items[i_cmd]
          (battler || pkmn).remove_item(old_item)
          pkmn.mail = nil if GameData::Item.get(old_item).is_mail?
        end
        (battler || pkmn).item = item
        pkmn.mail = Mail.new(item, _INTL("Text"), $player.name) if GameData::Item.get(item).is_mail?
      when 1
        if (battler || pkmn).item_count == 0
          pbMessage(_INTL("There are no items to remove."))
        elsif (battler || pkmn).item_count == 1
          (battler || pkmn).item = nil
          pkmn.mail = nil
        else
          i_commands = []
          (battler || pkmn).each_item { |i| i_commands.push(i.name) }
          i_commands.insert(0, _INTL("Remove all Items"))
          i_cmd = pbMessage("\\ts[]" + _INTL("Choose items to remove."), i_commands, 0)
          next if i_cmd < 0
          if i_cmd == 0
            (battler || pkmn).items.clear
            pbMessage(_INTL("All of {1}'s items were removed.", pkmn.name))
          else
            item = pkmn.items[i_cmd - 1]
            (battler || pkmn).remove_item(item)
            pkmn.mail = nil if GameData::Item.get(item).is_mail?
          end
        end
      else
        break
      end
    end
    next false
  }
})
