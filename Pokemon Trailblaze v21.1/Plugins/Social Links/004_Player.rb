#===============================================================================
# Player
#===============================================================================
class Player < Trainer
    attr_accessor :social_links
    attr_accessor :bond_effects

    alias tdw_social_player_init initialize
    def initialize(name, trainer_type)
        tdw_social_player_init(name, trainer_type)
        @social_links = SocialLinks.new
        @bond_effects = {
            :EXP    => [],
            :Shiny  => [],
            :CatchRate => []
        }
    end

    def social_links
        @social_links = SocialLinks.new if !@social_links
        return @social_links
    end

    def bond_effects
        if !@bond_effects
            @bond_effects = {
                :EXP    => [],
                :Shiny  => [],
                :CatchRate => []
            }
        end
        @bond_effects[:CatchRate] = [] if !@bond_effects[:CatchRate]
        return @bond_effects
    end

    def active_bond_effect?(style, pkmn)
        return nil if !bond_effects || !bond_effects[style]
        array = bond_effects[style]
        case style
        when :EXP
            rate = nil
            array.each do |bond|
                rate = bond[1] if pkmn.hasType?(bond[0]) && (rate.nil? || bond[1] > rate)
            end
            return rate
        when :Shiny
            rolls = nil
            array.each do |bond|
                rolls = bond[1] if pkmn.hasType?(bond[0]) && (rolls.nil? || bond[1] > rolls)
            end
            return rolls
        when :CatchRate
            rate = nil
            array.each do |bond|
                rate = bond[1] if pkmn.hasType?(bond[0]) && (rate.nil? || bond[1] > rate)
            end
            return rate
        end
    end

    def refresh_bond_effects(profile_id, bond, silent = false)
        effects = GameData::SocialLinkProfile.get(profile_id)&.bond_effects
        effects.each do |key, val|
            val.each do |effect_type, type, rate|
                case effect_type
                when :EXP
                    array = [type, rate || 1.1, profile_id]
                when :Shiny
                    array = [type, rate || 1, profile_id]
                when :CatchRate
                    array = [type, rate || 1.1, profile_id]
                end
                if bond < key && bond_effects[effect_type] && bond_effects[effect_type].include?(array)
                    bond_effects[effect_type].delete(array)
                elsif bond >= key && !bond_effects[effect_type].include?(array)
                    bond_effects[effect_type].push(array)
                    if SocialLinkSettings::SHOW_BOND_EFFECT_MESSAGE && !silent
                        type_name = GameData::Type.get(array[0]).name
                        case effect_type
                        when :EXP
                            if array[1] > 1
                                pbMessage(_INTL("Your {1}-type Pokémon will now gain more Exp. Points!", type_name))
                            elsif array[1] < 1
                                pbMessage(_INTL("Your {1}-type Pokémon will now gain less Exp. Points.", type_name))
                            end
                        when :Shiny
                            if array[1] >= 1
                                pbMessage(_INTL("{1}-type Pokémon will now have a higher chance of being Shiny!", type_name))
                            elsif array[1] < 0
                                pbMessage(_INTL("{1}-type Pokémon will now have a lower chance of being Shiny.", type_name))
                            end 
                        when :CatchRate
                            if array[1] > 1
                                pbMessage(_INTL("{1}-type Pokémon will now be easier to catch!", type_name))
                            elsif array[1] < 1
                                pbMessage(_INTL("{1}-type Pokémon will now be harder to catch.", type_name))
                            end
                        end
                    end
                end
            end
        end
    end

    class SocialLinks
        attr_accessor :links
        attr_accessor :theme_color

        def initialize
            @links = {}
            @theme_color = SocialLinkSettings::DEFAULT_THEME_COLOR
        end

        def pbSanitizeProfileID(object)
            return object if object.is_a?(Symbol)
            actual_id = nil
            if object.is_a?(Game_Event)
                actual_id = $~[1].to_sym if object.name[/sociallink\(:(\w+)\)$/i]
            elsif object.is_a?(Interpreter)
                event = object.get_character
                actual_id = $~[1].to_sym if event.name[/sociallink\(:(\w+)\)$/i]
            end
            if actual_id.nil?
                event = (object.is_a?(Interpreter) ? object.get_character : object)
                Console.echo_warn _INTL("Social Links plugin: Invalid use of self argument. A SocialLink(:ID_HERE) label is not included in the event name. Info: Event {1} {2} on Map {3}", 
                    event.id, event.name, event.map_id)
            end
            return actual_id
        end

        def pbAddLink(profile_id, silent: false)
            profile_id = pbSanitizeProfileID(profile_id)
            return false if profile_id.nil?
            return false if pbHasLink?(profile_id)
            array = @links.to_a
            array.unshift([profile_id, SocialLinkProfile.new(profile_id)])
            @links = array.to_h
            unless silent
                pbSEPlay(SocialLinkSettings::NEW_LINK_SOUND_EFFECT)
                pbMessage(_INTL(SocialLinkSettings::NEW_LINK_MESSAGE + "\\wtnp[40]", @links[profile_id].name))
            end
            return true
        end

        def pbRemoveLink(profile_id, silent: false)
            profile_id = pbSanitizeProfileID(profile_id)
            return false if profile_id.nil?
            return false unless pbHasLink?(profile_id)
            unless silent
                pbMessage(_INTL(SocialLinkSettings::REMOVED_LINK_MESSAGE, @links[profile_id].name))
            end
            @links.delete(profile_id)
            return true
        end

        def pbHasLink?(profile_id)
            profile_id = pbSanitizeProfileID(profile_id)
            return false if profile_id.nil?
            return false if @links[profile_id].nil?
            return true
        end

        def pbGainLinkBond(profile_id, val = 1, silent: false)
            profile_id = pbSanitizeProfileID(profile_id)
            return false if profile_id.nil?
            return false if !@links[profile_id]
            old_val = @links[profile_id].bond
            @links[profile_id].bond += val
            max_bond = @links[profile_id].bond_max
            @links[profile_id].bond = max_bond if @links[profile_id].bond > max_bond
            if old_val != @links[profile_id].bond
                unless silent
                    if @links[profile_id].bond == max_bond && SocialLinkSettings::SHOW_MAXED_BOND_MESSAGE
                        pbSEPlay(SocialLinkSettings::MAXED_BOND_SOUND_EFFECT)
                        pbMessage(_INTL(SocialLinkSettings::MAXED_BOND_MESSAGE + "", @links[profile_id].name))
                    elsif val == 1
                        pbMessage(_INTL("Your bond with {1} grew a bit stronger!", @links[profile_id].name))
                    elsif val == 2
                        pbMessage(_INTL("Your bond with {1} grew stronger!", @links[profile_id].name))
                    else
                        pbMessage(_INTL("Your bond with {1} grew a lot stronger!", @links[profile_id].name))
                    end
                end
                @links[profile_id].moments = 0 if SocialLinkSettings::RESET_MOMENTS_ON_BOND_INCREASE
                $player.refresh_bond_effects(profile_id, @links[profile_id].bond, silent) if GameData::SocialLinkProfile.get(profile_id)&.bond_effects
                return true
            end
            return false
        end

        def pbLowerLinkBond(profile_id, val = 1, silent: false)
            profile_id = pbSanitizeProfileID(profile_id)
            return false if profile_id.nil?
            return false if !@links[profile_id]
            old_val = @links[profile_id].bond
            @links[profile_id].bond -= val
            @links[profile_id].bond = 0 if @links[profile_id].bond < 0
            if old_val != @links[profile_id].bond
                unless silent
                    if val == 1
                        pbMessage(_INTL("Your bond with {1} has weakened a bit.", @links[profile_id].name))
                    elsif val == 2
                        pbMessage(_INTL("Your bond with {1} has weakened.", @links[profile_id].name))
                    else
                        pbMessage(_INTL("Your bond with {1} has weakened significantly.", @links[profile_id].name))
                    end
                end
                $player.refresh_bond_effects(profile_id, @links[profile_id].bond, silent) if GameData::SocialLinkProfile.get(profile_id)&.bond_effects
                return true
            end
            return false
        end

        def pbSetLinkBond(profile_id, val = 1, silent: false)
            profile_id = pbSanitizeProfileID(profile_id)
            return false if profile_id.nil?
            return false if !@links[profile_id]
            old_val = @links[profile_id].bond
            @links[profile_id].bond = val
            max_bond = @links[profile_id].bond_max
            @links[profile_id].bond.clamp(0, max_bond)
            if old_val != @links[profile_id].bond
                if old_val > @links[profile_id].bond && !silent
                    if val == 1
                        pbMessage(_INTL("Your bond with {1} has weakened a bit.", @links[profile_id].name))
                    elsif val == 2
                        pbMessage(_INTL("Your bond with {1} has weakened.", @links[profile_id].name))
                    else
                        pbMessage(_INTL("Your bond with {1} has weakened significantly.", @links[profile_id].name))
                    end
                elsif old_val < @links[profile_id].bond && !silent
                    if @links[profile_id].bond == max_bond && SocialLinkSettings::SHOW_MAXED_BOND_MESSAGE
                        pbSEPlay(SocialLinkSettings::MAXED_BOND_SOUND_EFFECT)
                        pbMessage(_INTL(SocialLinkSettings::MAXED_BOND_MESSAGE "", @links[profile_id].name))
                    elsif val == 1
                        pbMessage(_INTL("Your bond with {1} grew a bit stronger!", @links[profile_id].name))
                    elsif val == 2
                        pbMessage(_INTL("Your bond with {1} grew stronger!", @links[profile_id].name))
                    else
                        pbMessage(_INTL("Your bond with {1} grew a lot stronger!", @links[profile_id].name))
                    end
                    @links[profile_id].moments = 0 if SocialLinkSettings::RESET_MOMENTS_ON_BOND_INCREASE
                end
                $player.refresh_bond_effects(profile_id, @links[profile_id].bond, silent) if GameData::SocialLinkProfile.get(profile_id)&.bond_effects
                return true
            end
            return false
        end

        def pbGetLinkBond(profile_id)
            profile_id = pbSanitizeProfileID(profile_id)
            return 0 if profile_id.nil?
            return 0 if !@links[profile_id]
            return @links[profile_id].bond
        end

        def pbLinkBondMaxed?(profile_id)
            profile_id = pbSanitizeProfileID(profile_id)
            return false if profile_id.nil?
            return false if !@links[profile_id] || @links[profile_id].bond < @links[profile_id].bond_max
            return true
        end

        def pbGainLinkMoment(profile_id, val = 1, silent: false)
            profile_id = pbSanitizeProfileID(profile_id)
            return false if profile_id.nil?
            return false if !@links[profile_id]
            old_val = @links[profile_id].moments
            @links[profile_id].moments += val
            max_moments = @links[profile_id].moments_max
            @links[profile_id].moments = max_moments if @links[profile_id].moments > max_moments
            if old_val != @links[profile_id].moments
                unless silent
                    # if @links[profile_id].moments == max_moments #&& SocialLinkSettings::SHOW_MAXED_BOND_MESSAGE
                    #     pbSEPlay(SocialLinkSettings::MAXED_BOND_SOUND_EFFECT)
                    #     pbMessage(_INTL(SocialLinkSettings::MAXED_BOND_MESSAGE + "", @links[profile_id].name))
                    if val == 1
                        pbMessage(_INTL("You shared a moment with {1}!", @links[profile_id].name))
                    else
                        pbMessage(_INTL("You shared a significant moment with {1}!", @links[profile_id].name))
                    end
                end
                return true
            end
            return false
        end

        def pbLowerLinkMoment(profile_id, val = 1, silent: false)
            profile_id = pbSanitizeProfileID(profile_id)
            return false if profile_id.nil?
            return false if !@links[profile_id]
            old_val = @links[profile_id].moments
            @links[profile_id].moments -= val
            @links[profile_id].moments = 0 if @links[profile_id].moments < 0
            if old_val != @links[profile_id].moments
                unless silent
                    if val == 1
                        pbMessage(_INTL("You shared an unfortunate moment with {1}.", @links[profile_id].name))
                    else
                        pbMessage(_INTL("You shared a significant, unfortunate moment with {1}.", @links[profile_id].name))
                    end
                end
                return true
            end
            return false
        end

        def pbSetLinkMoment(profile_id, val = 1, silent: false)
            profile_id = pbSanitizeProfileID(profile_id)
            return false if profile_id.nil?
            return false if !@links[profile_id]
            old_val = @links[profile_id].moments
            @links[profile_id].moments = val
            max_moments = @links[profile_id].moments_max
            @links[profile_id].moments.clamp(0, max_moments)
            if old_val != @links[profile_id].moments
                if old_val > @links[profile_id].moments && !silent
                    if val == 1
                        pbMessage(_INTL("You shared an unfortunate moment with {1}.", @links[profile_id].name))
                    else
                        pbMessage(_INTL("You shared a significant, unfortunate moment with {1}.", @links[profile_id].name))
                    end
                elsif old_val < @links[profile_id].bond && !silent
                    #if @links[profile_id].bond == max_bond && SocialLinkSettings::SHOW_MAXED_BOND_MESSAGE
                    #    pbSEPlay(SocialLinkSettings::MAXED_BOND_SOUND_EFFECT)
                    #    pbMessage(_INTL(SocialLinkSettings::MAXED_BOND_MESSAGE "", @links[profile_id].name))
                    if val == 1
                        pbMessage(_INTL("You shared a moment with {1}!", @links[profile_id].name))
                    else
                        pbMessage(_INTL("You shared a significant moment with {1}!", @links[profile_id].name))
                    end
                end
                return true
            end
            return false
        end

        def pbGetLinkMoments(profile_id)
            profile_id = pbSanitizeProfileID(profile_id)
            return 0 if profile_id.nil?
            return 0 if !@links[profile_id]
            return @links[profile_id].moments
        end

        def pbLinkMomentsMaxed?(profile_id)
            profile_id = pbSanitizeProfileID(profile_id)
            return false if profile_id.nil?
            return false if !@links[profile_id] || @links[profile_id].moments < @links[profile_id].moments_max
            return true
        end

        def pbSetLinkLocation(profile_id, location)
            profile_id = pbSanitizeProfileID(profile_id)
            return false if profile_id.nil?
            @links[profile_id].current_location = location
            return true
        end

        def pbSetLinkPokemon(profile_id, species, gender, form, shiny)
            profile_id = pbSanitizeProfileID(profile_id)
            return false if profile_id.nil?
            @links[profile_id].favorite_pokemon = species.nil? ? nil : [species, gender, form, shiny]
            return true
        end

        def pbSetLinkStatus(profile_id, status)
            profile_id = pbSanitizeProfileID(profile_id)
            return false if profile_id.nil?
            if status.is_a?(String)
                @links[profile_id].current_status = status
                return true
            elsif status.is_a?(Integer)
                data = GameData::SocialLinkProfile.get(profile_id)
                return false if !data.static_status_pool[status]
                return false if @links[profile_id].past_statuses.include?(data.static_status_pool[status])
                @links[profile_id].current_status = data.static_status_pool[status]
                @links[profile_id].past_statuses.push(data.static_status_pool[status])
                return true
            elsif status == :Random
                data = GameData::SocialLinkProfile.get(profile_id).random_status_pool
                pool = []
                data.each { |s| pool.push(s[0]) if (s[1].nil? || s[1] <= @links[profile_id].bond) && !@links[profile_id].past_statuses.include?(s[0]) }
                return false if pool.empty?
                r = rand(pool.length)
                @links[profile_id].current_status = pool[r]
                @links[profile_id].past_statuses.push(pool[r])
                return true
            end
            return false
        end

    end

end

def pbPlayerSocialLinksSaved
    return $player.social_links
end
