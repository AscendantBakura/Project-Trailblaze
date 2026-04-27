#===============================================================================
# * Gacha System Logic (Refined for Silent Addition & Pity System)
#===============================================================================

# Added dynamically to track player's pity correctly without losing compatibility using typical serialize/deserialize mechanisms.
class Player
  def gacha_pity
    @gacha_pity ||= {}
    return @gacha_pity
  end
  def gacha_pity=(value)
    @gacha_pity = value
  end
end

module GachaLogic
  
  # Gets a random prize from the given banner based on probabilities and pity
  def self.roll_prize(banner_id)
    banner = GachaConfig::BANNERS[banner_id]
    return nil if !banner || !banner[:pools]
    
    # Initialize pity for this specific banner
    $player.gacha_pity[banner_id] ||= 0
    current_pity = $player.gacha_pity[banner_id]
    
    pity_limit = banner[:pity_limit] || 9999
    soft_pity_start = banner[:soft_pity_start] || 9999
    soft_pity_increase = banner[:soft_pity_increase] || 0
    
    # HARD PITY: Check if the player has reached the limit
    if current_pity + 1 >= pity_limit
      main_prizes = banner[:pools].select { |p| p[:is_main_prize] }
      if main_prizes.length > 0
        prize = main_prizes.sample.clone
        if prize[:type] == :pokemon && prize[:shiny_chance] && rand(100) < prize[:shiny_chance]
          prize[:is_shiny] = true
        end
        $player.gacha_pity[banner_id] = 0 # Reset pity!
        return prize
      end
    end
    
    # Normal Roll with SOFT PITY Calculations
    total_weight = 0
    calculated_pools = []
    
    banner[:pools].each do |prize|
      weight = prize[:probability]
      
      # Apply soft pity if past the soft pity threshold, and only to main prizes
      if prize[:is_main_prize] && current_pity + 1 >= soft_pity_start
        rolls_past_soft_pity = (current_pity + 1) - soft_pity_start + 1
        weight += (rolls_past_soft_pity * soft_pity_increase)
      end
      
      total_weight += weight
      calculated_pools.push({prize: prize, weight: weight})
    end
    
    return nil if total_weight == 0
    
    random_val = rand(total_weight)
    current_weight = 0
    selected_prize = nil
    
    calculated_pools.each do |pool|
      current_weight += pool[:weight]
      if random_val < current_weight
        selected_prize = pool[:prize].clone
        if selected_prize[:type] == :pokemon && selected_prize[:shiny_chance] && rand(100) < selected_prize[:shiny_chance]
          selected_prize[:is_shiny] = true
        end
        break
      end
    end
    
    # Update Pity Counters
    if selected_prize
      if selected_prize[:is_main_prize]
        $player.gacha_pity[banner_id] = 0 # Reset pity when getting the main prize
      else
        $player.gacha_pity[banner_id] += 1
      end
    end
    
    return selected_prize
  end

  # Checks if the player can afford to roll the gacha X times
  def self.can_afford?(banner_id, times = 1)
    banner = GachaConfig::BANNERS[banner_id]
    return false if !banner
    
    cost_item = banner[:cost_item] || GachaConfig::DEFAULT_COST_ITEM
    cost_amount = (banner[:cost_amount] || 1) * times
    
    if cost_item == :MONEY
      return $player.money >= cost_amount
    else
      return $bag.has?(cost_item, cost_amount)
    end
  end

  # Pays the cost for the gacha X times
  def self.pay_cost(banner_id, times = 1)
    banner = GachaConfig::BANNERS[banner_id]
    return false if !banner
    
    cost_item = banner[:cost_item] || GachaConfig::DEFAULT_COST_ITEM
    cost_amount = (banner[:cost_amount] || 1) * times
    
    if cost_item == :MONEY
      if $player.money >= cost_amount
        $player.money -= cost_amount
        return true
      end
    else
      if $bag.remove(cost_item, cost_amount)
        return true
      end
    end
    return false
  end

  # Rolls multiple times and returns an array of prizes
  def self.roll_multiple(banner_id, times)
    prizes = []
    times.times do
      prizes.push(roll_prize(banner_id))
    end
    return prizes.compact
  end

  # Gives the prize to the player silently, returning the text to display and the obtained object (if any).
  def self.give_prize(prize)
    return ["", nil] if !prize
    
    if prize[:type] == :pokemon
      species = prize[:species]
      level = prize[:level]
      
      pkmn = Pokemon.new(species, level)
      if prize[:is_shiny]
        pkmn.shiny = true
      end
      if prize[:nature]
        pkmn.nature = prize[:nature]
      end
      if prize[:ability]
        pkmn.ability = prize[:ability]
      elsif prize[:ability_index]
        pkmn.ability_index = prize[:ability_index]
      end
      pkmn.calc_stats
      
      # pbAddPokemonSilent returns true if it was added to party or PC
      if pbAddPokemonSilent(pkmn)
        # Register in pokedex manually since silent doesn't do the full UI
        $player.pokedex.register(pkmn)
        $player.pokedex.set_owned(species)
        return [_INTL("You obtained a {1}!", pkmn.name), pkmn]
      else
        return [_INTL("There is no more room for Pokémon!"), nil]
      end
      
    elsif prize[:type] == :item
      item = prize[:item]
      amount = prize[:amount] || 1
      
      if $bag.can_add?(item, amount)
        $bag.add(item, amount)
        item_name = GameData::Item.get(item).name
        return [_INTL("You obtained {1} {2}!", amount, item_name), nil]
      else
        return [_INTL("Your bag is full!"), nil]
      end
    end
    return ["", nil]
  end
  
  # Gives multiple prizes to the player silently, returning the text to display.
  def self.give_multiple_prizes(prizes)
    return "" if prizes.empty?
    
    obtained_items = {}
    obtained_pkmn = []
    failed_pkmn = 0
    failed_items = 0
    
    prizes.each do |prize|
      if prize[:type] == :pokemon
        species = prize[:species]
        level = prize[:level]
        
        pkmn = Pokemon.new(species, level)
        if prize[:is_shiny]
          pkmn.shiny = true
        end
        if prize[:nature]
          pkmn.nature = prize[:nature]
        end
        if prize[:ability]
          pkmn.ability = prize[:ability]
        elsif prize[:ability_index]
          pkmn.ability_index = prize[:ability_index]
        end
        pkmn.calc_stats
        
        if pbAddPokemonSilent(pkmn)
          is_new = !$player.pokedex.owned?(species)
          $player.pokedex.register(pkmn)
          $player.pokedex.set_owned(species)
          obtained_pkmn.push({pkmn: pkmn, is_new: is_new})
        else
          failed_pkmn += 1
        end
        
      elsif prize[:type] == :item
        item = prize[:item]
        amount = prize[:amount] || 1
        
        if $bag.can_add?(item, amount)
          $bag.add(item, amount)
          obtained_items[item] ||= 0
          obtained_items[item] += amount
        else
          failed_items += 1
        end
      end
    end
    
    summary = []
    summary.push(_INTL("Obtained {1} Pokémon!", obtained_pkmn.length)) if obtained_pkmn.length > 0
    
    obtained_items.each do |item, amount|
      item_name = GameData::Item.get(item).name
      summary.push(_INTL("{1} {2}", amount, item_name))
    end
    
    summary.push(_INTL("({1} Pokémon failed - No room)", failed_pkmn)) if failed_pkmn > 0
    summary.push(_INTL("({1} Items failed - Bag full)", failed_items)) if failed_items > 0
    
    return [summary.join("\n"), obtained_pkmn]
  end
  
end
