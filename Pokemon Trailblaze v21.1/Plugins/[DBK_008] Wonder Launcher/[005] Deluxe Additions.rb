#===============================================================================
# Game stat tracking for Wonder Launcher.
#===============================================================================
class GameStats
  alias launcher_initialize initialize
  def initialize
    launcher_initialize
    @wonder_launcher_battles_won = 0
    @wonder_launcher_item_count  = 0
  end
  
  def wonder_launcher_item_count
    return @wonder_launcher_item_count || 0
  end
  
  def wonder_launcher_item_count=(value)
    @wonder_launcher_item_count = 0 if !@wonder_launcher_item_count
    @wonder_launcher_item_count = value
  end
  
  def wonder_launcher_battles_won
    return @wonder_launcher_battles_won || 0
  end
  
  def wonder_launcher_battles_won=(value)
    @wonder_launcher_battles_won = 0 if !@wonder_launcher_battles_won
    @wonder_launcher_battles_won = value
  end
end


#===============================================================================
# Adds new Battle Rules related to the Wonder Launcher.
#===============================================================================
class Game_Temp
  attr_accessor :wonder_launcher_mode, :player_launcher_points
  
  alias launcher_add_battle_rule add_battle_rule
  def add_battle_rule(rule, var = nil)
    rules = self.battle_rules
    case rule.to_s.downcase
    when "wonderlauncher"   then rules["wonderLauncher"] = true   # Enables Wonder Launcher
    when "nowonderlauncher" then rules["wonderLauncher"] = false  # Disables Wonder Launcher
    else
      launcher_add_battle_rule(rule, var)
    end
  end
end

module BattleCreationHelperMethods
  module_function
  
  BattleCreationHelperMethods.singleton_class.alias_method :launcher_prepare_battle, :prepare_battle
  def prepare_battle(battle)
    BattleCreationHelperMethods.launcher_prepare_battle(battle)
    if battle.trainerBattle?
      battleRules = $game_temp.battle_rules
      ruleDefault = $game_switches[Settings::WONDER_LAUNCHER_SWITCH]
      $game_temp.battle_rules["wonderLauncher"] = true if ruleDefault && battleRules["wonderLauncher"].nil?
      battle.wonderLauncher = battleRules["wonderLauncher"] if !battleRules["wonderLauncher"].nil?
      if battle.wonderLauncher
        $game_temp.wonder_launcher_mode = true
        battle.launcherItems = GameData::Item.get_launcher_items
        2.times do |i|
          battle.launcherCounter[i].length.times do |t|
            battle.launcherCounter[i][t] = true
          end
        end
      end
    end
  end
end


#===============================================================================
# Midbattle scripting
#===============================================================================

#-------------------------------------------------------------------------------
# General Wonder Launcher battle script.
#-------------------------------------------------------------------------------
MidbattleHandlers.add(:midbattle_global, :wonder_launcher_battle,
  proc { |battle, idxBattler, idxTarget, trigger|
    next if !battle.launcherBattle?
    case trigger
    when "RoundStartCommand_1_player"
      next if battle.pbTriggerActivated?(trigger)
      battle.noBag = false
      2.times do |side|
        trainers = (side == 0) ? battle.player : battle.opponent
        trainers.length.times do |i|
          battle.pbSetLauncherItems(side, i)
        end
      end
    when "BattleEndWin"
      $stats.wonder_launcher_battles_won += 1
      $game_temp.wonder_launcher_mode = false
      $game_temp.player_launcher_points = 0
    end
  }
)

#-------------------------------------------------------------------------------
# Sets the number of Wonder Launcher points for a trainer.
#-------------------------------------------------------------------------------
MidbattleHandlers.add(:midbattle_triggers, "setLP",
  proc { |battle, idxBattler, idxTarget, params|
    if params.is_a?(Array)
      pnts, idx = *params
    else
      pnts, idx = params, idxBattler
    end
    index = battle.scene.pbConvertBattlerIndex(idxBattler, idxTarget, idx)
    side = (battle.battlers[index].opposes?) ? 1 : 0
    idxTrainer = battle.pbGetOwnerIndexFromBattlerIndex(index)
    if battle.launcherCounter[side][idxTrainer] && !battle.pbTeamAllFainted?(side, idxTrainer)
      trainerName = battle.pbGetOwnerName(index)
      maxPoints = Settings::WONDER_LAUNCHER_MAX_POINTS
      oldPoints = battle.launcherPoints[side][idxTrainer]
      newPoints = oldPoints += pnts
      if newPoints > maxPoints
        newPoints = maxPoints
      elsif newPoints < 0
        newPoints = 0
      end
      battle.launcherPoints[side][idxTrainer] = newPoints
      $game_temp.player_launcher_points = newPoints if side == 0 && idxTrainer == 0
      if pnts > 0
        PBDebug.log("     'setLP': #{trainerName}'s Launcher Points increased by #{pnts} (#{oldPoints} -> #{newPoints})")
      else
        PBDebug.log("     'setLP': #{trainerName}'s Launcher Points reduced by #{pnts.abs} (#{oldPoints} -> #{newPoints})")
      end
      battle.scene.pbShowLauncherPoints(side, idxTrainer, newPoints)
      battle.scene.pbHideAllLauncherPoints
    end
  }
)

#-------------------------------------------------------------------------------
# Toggles a trainer's ability to use and accumulate Wonder Launcher points.
#-------------------------------------------------------------------------------
MidbattleHandlers.add(:midbattle_triggers, "disableLP",
  proc { |battle, idxBattler, idxTarget, params|
    next if !battle.battlers[idxBattler]
    battle.pbToggleLauncher(idxBattler, !params)
    value = (params) ? "disabled" : "enabled"
    trainerName = battle.pbGetOwnerName(idxBattler)
    PBDebug.log("     'disableLP': Wonder Launcher points #{value} for #{trainerName}")
  }
)