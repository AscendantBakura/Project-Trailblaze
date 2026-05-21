MenuHandlers.add(:options_menu, :tb_turbo_frameskip, {
  "name"        => _INTL("Frame skip"),
  "order"       => TrailblazeSpeedUp::OPTIONS_ORDER_FRAMESKIP,
  "type"        => EnumOption,
  "parameters"  => [_INTL("Off"), _INTL("On")],
  "description" => _INTL("Allows turbo speed to go beyond refresh rate by skipping frames."),
  "get_proc"    => proc { next $PokemonSystem&.tb_turbo_frameskip.to_i || 0 },
  "set_proc"    => proc { |value, _scene|
    $PokemonSystem.tb_turbo_frameskip = value
    TrailblazeSpeedUp.apply_frameskip
  }
})

MenuHandlers.add(:options_menu, :tb_turbo_speed, {
  "name"        => _INTL("Turbo Speed"),
  "order"       => TrailblazeSpeedUp::OPTIONS_ORDER_TURBO_SPEED,
  "type"        => EnumOption,
  "parameters"  => TrailblazeSpeedUp::TURBO_MULTIPLIERS.map { |m| _INTL("x{1}", (m % 1.0 == 0.0) ? m.to_i : m) },
  "description" => _INTL("Game speed multiplier while in Turbo Mode."),
  "get_proc"    => proc {
    current = TrailblazeSpeedUp.multiplier
    closest_index = 0
    closest_delta = (TrailblazeSpeedUp::TURBO_MULTIPLIERS[0] - current).abs
    TrailblazeSpeedUp::TURBO_MULTIPLIERS.each_with_index do |value, index|
      delta = (value - current).abs
      next if delta >= closest_delta

      closest_index = index
      closest_delta = delta
    end
    next closest_index
  },
  "set_proc"    => proc { |value, _scene|
    index = [[value.to_i, 0].max, TrailblazeSpeedUp::TURBO_MULTIPLIERS.length - 1].min
    $PokemonSystem.tb_turbo_speed_multiplier = TrailblazeSpeedUp::TURBO_MULTIPLIERS[index]
    TrailblazeSpeedUp.apply_turbo_state(true) if $speed_up
  }
})
