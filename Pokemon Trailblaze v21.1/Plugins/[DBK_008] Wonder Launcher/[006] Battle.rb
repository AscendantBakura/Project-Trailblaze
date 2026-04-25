#===============================================================================
# Battle class.
#===============================================================================
class Battle
  attr_accessor :wonderLauncher, :launcherItems, :launcherPoints, :launcherCounter
  
  #-----------------------------------------------------------------------------
  # Used to check if the Wonder Launcher is enabled for this battle.
  #-----------------------------------------------------------------------------
  def launcherBattle?
    return false if !trainerBattle?
    return @wonderLauncher
  end
  
  #-----------------------------------------------------------------------------
  # Used to check if a trainer is able to use the Wonder Launcher.
  #-----------------------------------------------------------------------------
  def pbCanUseLauncher?(idxBattler)
    return false if !launcherBattle?
    idxBattler = idxBattler.index if idxBattler.respond_to?("index")
    side = (@battlers[idxBattler].opposes?) ? 1 : 0
    index = pbGetOwnerIndexFromBattlerIndex(idxBattler)
    return @launcherCounter[side][index] || false
  end
  
  #-----------------------------------------------------------------------------
  # Used to toggle a trainer's ability to use and accumulate Wonder Launcher points.
  #-----------------------------------------------------------------------------
  def pbToggleLauncher(idxBattler, toggle = nil)
    return if !launcherBattle?
    idxBattler = idxBattler.index if idxBattler.respond_to?("index")
    side = (@battlers[idxBattler].opposes?) ? 1 : 0
    index = pbGetOwnerIndexFromBattlerIndex(idxBattler)
    trainerName = pbGetOwnerName(idxBattler)
    counter = @launcherCounter[side][index]
    @launcherCounter[side][index] = (toggle.nil?) ? !counter : toggle
  end
  
  #-----------------------------------------------------------------------------
  # Specifically used for increasing Wonder Launcher points at the start of each turn.
  #-----------------------------------------------------------------------------
  def pbStartTurnLauncher(idxSide, idxTrainer)
    return if !launcherBattle?
    maxPoints = Settings::WONDER_LAUNCHER_MAX_POINTS
    return if !@launcherCounter[idxSide][idxTrainer]
    trainer = (idxSide == 0) ? @player : @opponent
    return if !trainer || pbTeamAllFainted?(idxSide, idxTrainer)
    trainerName = (idxSide == 1 || idxTrainer > 0) ? trainer[idxTrainer].full_name : trainer[idxTrainer].name
    oldPoints = @launcherPoints[idxSide][idxTrainer]
    if oldPoints >= maxPoints
      @launcherPoints[idxSide][idxTrainer] = maxPoints
    else
      points = Settings::WONDER_LAUNCHER_POINTS_PER_TURN
      allySide = @battlers.select { |b| b && !b.fainted? && !b.opposes?(idxSide) }
      foeSide = @battlers.select { |b| b && !b.fainted? && b.opposes?(idxSide) }
      points += 1 if foeSide.length > allySide.length
      @launcherPoints[idxSide][idxTrainer] += points
      @launcherPoints[idxSide][idxTrainer] = maxPoints if @launcherPoints[idxSide][idxTrainer] > maxPoints
    end
    newPoints = @launcherPoints[idxSide][idxTrainer]
    $game_temp.player_launcher_points = newPoints if idxSide == 0 && idxTrainer == 0
    points = newPoints - oldPoints
    PBDebug.log("[Wonder Launcher] #{trainerName}'s Launcher Points increased by #{points} (#{oldPoints} -> #{newPoints})")
    @scene.pbShowLauncherPoints(idxSide, idxTrainer, newPoints) if Settings::SHOW_LAUNCHER_SPLASH_EACH_TURN
    idxBattler = (idxSide == 0) ? idxTrainer * 2 : idxTrainer * 2 + 1
    pbDeluxeTriggers(idxBattler, nil, "TrainerGainedLP")
  end
  
  #-----------------------------------------------------------------------------
  # Utilities used for changing the number of Wonder Launcher points a trainer has.
  #-----------------------------------------------------------------------------
  def pbIncreaseLauncherPoints(idxBattler, points, showBar = false)
    return if !launcherBattle?
    idxBattler = idxBattler.index if idxBattler.respond_to?("index")
    side = (@battlers[idxBattler].opposes?) ? 1 : 0
    index = pbGetOwnerIndexFromBattlerIndex(idxBattler)
    maxPoints = Settings::WONDER_LAUNCHER_MAX_POINTS
    return if !@launcherCounter[side][index]
    return if @launcherPoints[side][index] == maxPoints
    return if pbTeamAllFainted?(side, index)
    trainerName = pbGetOwnerName(idxBattler)
    oldPoints = @launcherPoints[side][index]
    @launcherPoints[side][index] += points
    @launcherPoints[side][index] = maxPoints if @launcherPoints[side][index] > maxPoints
    newPoints = @launcherPoints[side][index]
    $game_temp.player_launcher_points = newPoints if pbOwnedByPlayer?(idxBattler)
    if newPoints > oldPoints
      PBDebug.log("[Wonder Launcher] #{trainerName}'s Launcher Points increased by #{points} (#{oldPoints} -> #{newPoints})")
      if showBar
        @scene.pbShowLauncherPoints(side, index, newPoints)
        @scene.pbHideAllLauncherPoints
      end
      pbDeluxeTriggers(idxBattler, nil, "TrainerGainedLP")
    end
  end
  
  def pbReduceLauncherPoints(idxBattler, item, showBar = false)
    return if !launcherBattle?
    item = GameData::Item.try_get(item)
    if item
      points = item.launcher_points
      return if points <= 0
      idxBattler = idxBattler.index if idxBattler.respond_to?("index")
      side = (@battlers[idxBattler].opposes?) ? 1 : 0
      index = pbGetOwnerIndexFromBattlerIndex(idxBattler)
      return if !@launcherCounter[side][index]
      return if @launcherPoints[side][index] < points
      return if pbTeamAllFainted?(side, index)
      trainerName = pbGetOwnerName(idxBattler)
      oldPoints = @launcherPoints[side][index]
      @launcherPoints[side][index] -= points
      @launcherPoints[side][index] = 0 if @launcherPoints[side][index] < 0
      newPoints = @launcherPoints[side][index]
      if pbOwnedByPlayer?(idxBattler)
        $stats.wonder_launcher_item_count += 1
        $game_temp.player_launcher_points = newPoints
      end
      if newPoints < oldPoints
        PBDebug.log("[Wonder Launcher] #{trainerName}'s Launcher Points reduced by #{points} (#{oldPoints} -> #{newPoints})")
        if showBar
          @scene.pbShowLauncherPoints(side, index, newPoints)
          @scene.pbHideAllLauncherPoints
        end
        pbDeluxeTriggers(idxBattler, nil, "TrainerLostLP")
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Utilities for setting the Wonder Launcher inventory for each trainer.
  #-----------------------------------------------------------------------------
  def pbSetLauncherItems(idxSide, idxTrainer)
    return if !launcherBattle?
    newItems = []
    case idxSide
    #---------------------------------------------------------------------------
    # Player's side items
    when 0
      case idxTrainer
      when 0 # Player
        $game_temp.old_player_bag = $bag.clone
        pocket = $bag.get_key_items_pocket
        $bag.pockets[pocket].each { |i| newItems.push(i[0]) } if pocket >= 0
        $bag = PokemonBag.new
        newItems.concat(@launcherItems)
        newItems = pbSpecialItemCheck(newItems)
        newItems.each { |item| $bag.add(item) }
      else   # Partner trainer
        @ally_items[idxTrainer].each do |item|
          next if !GameData::Item.get(item).is_key_item?
          newItems.push(item)
        end
        newItems.concat(@launcherItems)
        newItems = pbSpecialItemCheck(newItems)
      end
      @ally_items[idxTrainer] = newItems
      PBDebug.log("[Midbattle Global] #{@player[idxTrainer].full_name} given Wonder Launcher inventory")
    #---------------------------------------------------------------------------
    # Opponent's side items
    when 1
      @items[idxTrainer].each do |item|
        next if !GameData::Item.get(item).is_key_item?
        newItems.push(item)
      end
      newItems.concat(@launcherItems)
      newItems = pbSpecialItemCheck(newItems)
      @items[idxTrainer] = newItems
      PBDebug.log("[Midbattle Global] #{@opponent[idxTrainer].full_name} given Wonder Launcher inventory")
    end
  end
  
  def pbSpecialItemCheck(items)
    [:ZBOOSTER, :WISHINGSTAR, :RADIANTTERAJEWEL].each do |item|
      next if !items.include?(item)
      case item
      when :ZBOOSTER         then array = @z_rings       || []
      when :WISHINGSTAR      then array = @dynamax_bands || []
      when :RADIANTTERAJEWEL then array = @tera_orbs     || []
      end
      items.delete(item) if !array.any? { |itm| items.include?(itm) }
    end
    return items
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to initialize Wonder Launcher properties.
  #-----------------------------------------------------------------------------
  alias launcher_initialize initialize
  def initialize(scene, p1, p2, player, opponent)
    launcher_initialize(scene, p1, p2, player, opponent)
    @wonderLauncher  = false
    @launcherItems   = nil
    @launcherPoints  = [Array.new(@party1.length, 0), Array.new(@party2.length, 0)]
    @launcherCounter = [Array.new(@party1.length, false), Array.new(@party2.length, false)]
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to allow certain items to be targetable with the Wonder Launcher.
  #-----------------------------------------------------------------------------
  alias launcher_pbMoveCanTarget? pbMoveCanTarget?
  def pbMoveCanTarget?(idxUser, idxTarget, target_data)
    ret = launcher_pbMoveCanTarget?(idxUser, idxTarget, target_data)
    return true if ret && target_data.id == :UserOrOther
    return ret
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for altered item use messages when using the Wonder Launcher.
  #-----------------------------------------------------------------------------
  alias launcher_pbUseItemMessage pbUseItemMessage
  def pbUseItemMessage(item, trainerName, pkmn = nil)
    if launcherBattle?
      item_data = GameData::Item.get(item)
      itemName = item_data.portion_name
      if item_data.has_flag?("UsesAllBattleActions")
        pbDisplayBrief(_INTL("{1} launched the {2}.", trainerName, itemName))
      elsif item_data.launcher_use == 5
        pbDisplayBrief(_INTL("{1} launched the {2} toward {3}.", trainerName, itemName, pkmn.pbTeam(true)))
      elsif pkmn.is_a?(Battle::Battler)
        pbDisplayBrief(_INTL("{1} launched the {2} toward {3}.", trainerName, itemName, pkmn.pbThis(true)))
      elsif pkmn.is_a?(Pokemon)
        pbDisplayBrief(_INTL("{1} launched the {2} toward {3}.", trainerName, itemName, pkmn.name))
      else
        pbDisplayBrief(_INTL("{1} launched the {2}.", trainerName, itemName))
      end
    else
      launcher_pbUseItemMessage(item, trainerName, pkmn)
    end
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for item usage when Wonder Launcher is active.
  #-----------------------------------------------------------------------------
  alias launcher_pbAttackPhaseItems pbAttackPhaseItems
  def pbAttackPhaseItems
    if launcherBattle?
      pbPriority.each do |b|
        next unless @choices[b.index][0] == :UseItem && !b.fainted?
        b.lastMoveFailed = false
        item = @choices[b.index][1]
        next if !item
        case GameData::Item.get(item).launcher_use
        when 1, 2
          pbUseItemOnPokemon(item, @choices[b.index][2], b) if @choices[b.index][2] >= 0
        when 3
          pbUseItemOnBattler(item, @choices[b.index][2], b)
        when 4, 6
          pbUsePokeBallInBattle(item, @choices[b.index][2], b)
        when 5
          pbUseItemInBattle(item, @choices[b.index][2], b)
        else
          next
        end
        return if @decision > 0
      end
      pbCalculatePriority if Settings::RECALCULATE_TURN_ORDER_AFTER_SPEED_CHANGES
    else
      launcher_pbAttackPhaseItems
    end
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for Wonder Launcher items that may target opposing battlers.
  #-----------------------------------------------------------------------------
  alias launcher_pbUsePokeBallInBattle pbUsePokeBallInBattle
  def pbUsePokeBallInBattle(item, idxBattler, userBattler)
    if launcherBattle? && !GameData::Item.get(item).is_poke_ball?
      pbDeluxeTriggers(userBattler, idxBattler, "BeforeItemUse", item)
      trainerName = pbGetOwnerName(userBattler.index)
      battler = @battlers[idxBattler]
      pkmn = battler.pokemon
      ch = @choices[userBattler.index]
      pbUseItemMessage(item, trainerName, battler)
      if ItemHandlers.triggerCanUseInBattle(item, pkmn, battler, ch[3], true, self, @scene, false, userBattler.index)
        @scene.pbItemUseAnimation(battler.index)
        ItemHandlers.triggerUseInBattle(item, battler, self)
        pbDeluxeTriggers(userBattler, idxBattler, "AfterItemUse", item)
        pbReduceLauncherPoints(userBattler, item, true)
        ch[1] = nil
        return
      end
      pbDisplay(_INTL("But it had no effect!"))
      pbReturnUnusedItemToBag(item, userBattler.index)
    else
      launcher_pbUsePokeBallInBattle(item, idxBattler, userBattler)
    end
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to edit the bag menu functionality while viewing Wonder Launcher items.
  #-----------------------------------------------------------------------------
  alias launcher_pbItemMenu pbItemMenu
  def pbItemMenu(idxBattler, firstAction)
    if launcherBattle?
      if !pbCanUseLauncher?(idxBattler)
        pbDisplay(_INTL("The Wonder Launcher can't be used!"))
        return false
      elsif @battlers[idxBattler].allAllies.any? { |b| b.pbOwnedByPlayer? && @choices[b.index][0] == :UseItem }
        pbDisplay(_INTL("The Wonder Launcher is already in use this turn."))
        return false
      end
      ret = false
      @scene.pbLauncherMenu(idxBattler) do |item, useType, idxPkmn, idxMove, itemScene|
        next false if !item
        battler = pkmn = nil
        case useType
        when 1, 2
          next false if !ItemHandlers.hasBattleUseOnPokemon(item)
          battler = pbFindBattler(idxPkmn, idxBattler)
          pkmn    = pbParty(idxBattler)[idxPkmn]
          next false if !pbCanUseItemOnPokemon?(item, pkmn, battler, itemScene)
        when 3
          next false if !ItemHandlers.hasBattleUseOnBattler(item)
          battler = pbFindBattler(idxPkmn, idxBattler)
          pkmn    = battler.pokemon if battler
          next false if !pbCanUseItemOnPokemon?(item, pkmn, battler, itemScene)
        when 4, 6
          next false if idxPkmn < 0
          battler = @battlers[idxPkmn]
          pkmn    = battler.pokemon if battler
        when 5
          battler = @battlers[idxBattler]
          pkmn    = battler.pokemon if battler
        else
          next false
        end
        next false if !pkmn
        next false if !ItemHandlers.triggerCanUseInBattle(item, pkmn, battler, idxMove,
                                                          firstAction, self, itemScene, true, idxBattler)
        next false if !pbRegisterItem(idxBattler, item, idxPkmn, idxMove)
        ret = true
        next true
      end
      return ret
    else
      return launcher_pbItemMenu(idxBattler, firstAction)
    end
  end
end