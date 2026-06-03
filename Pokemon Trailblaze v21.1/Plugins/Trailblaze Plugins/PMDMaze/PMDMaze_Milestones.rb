module PMDDungeon
  def self.milestone_for_floor(floor)
    MilestoneConfig::MILESTONES.find { |m| m[:floor] == floor }
  end

  def self.handle_milestone(milestone)
    case milestone[:type]

    when :teleport_away
      pbMessage(milestone[:message]) if milestone[:message] && !milestone[:message].empty?
      dest = milestone[:destination_map]
      x = milestone[:x] || 0
      y = milestone[:y] || 0
      pbFadeOutIn do
        $game_temp.player_new_map_id    = dest
        $game_temp.player_new_x        = x
        $game_temp.player_new_y        = y
        $game_temp.player_new_direction = 2
        $scene.transfer_player
        $game_map.autoplay
        $game_map.refresh
      end
      reset_run_state!
      return true

    when :rest_area
      msg = milestone[:message]
      dest = milestone[:destination_map]
      x = milestone[:x] || 0
      y = milestone[:y] || 0
      pbFadeOutIn do
        $game_temp.player_new_map_id    = dest
        $game_temp.player_new_x        = x
        $game_temp.player_new_y        = y
        $game_temp.player_new_direction = 2
        $scene.transfer_player
        $game_map.autoplay
        $game_map.refresh
      end
      pbMessage(msg) if msg && !msg.empty?
      return true

    when :end_of_area
      pbMessage(milestone[:message]) if milestone[:message] && !milestone[:message].empty?
      reset_run_state!
      return true

    when :boss
      pbMessage(milestone[:message_before]) if milestone[:message_before] && !milestone[:message_before].empty?
      species = milestone[:species]
      level   = milestone[:level] || 30
      pkmn    = Pokemon.new(species, level)
      success = pbWildBattle(species, level)
      if success
        pbMessage(milestone[:message_win]) if milestone[:message_win] && !milestone[:message_win].empty?
        if milestone[:destination_map]
          dest = milestone[:destination_map]
          x    = milestone[:x] || 0
          y    = milestone[:y] || 0
          pbFadeOutIn do
            $game_temp.player_new_map_id    = dest
            $game_temp.player_new_x        = x
            $game_temp.player_new_y        = y
            $game_temp.player_new_direction = 2
            $scene.transfer_player
            $game_map.autoplay
            $game_map.refresh
          end
          return true
        end
        return false
      else
        reset_run_state!
        return true
      end

    end
    return false
  end
end
