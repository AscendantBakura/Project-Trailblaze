# Raid data must outlive rewards, but must never become the next wild encounter.
module TrailblazeRaidLifecycle
  def start(*args)
    previous_partner = $PokemonGlobal.partner
    super
  ensure
    $PokemonGlobal.partner = previous_partner
    $game_temp.clear_battle_rules
    $game_temp.transition_animation_data = nil
    $raid_reward_screen_data = nil
  end
end

RaidBattle.singleton_class.prepend(TrailblazeRaidLifecycle)
