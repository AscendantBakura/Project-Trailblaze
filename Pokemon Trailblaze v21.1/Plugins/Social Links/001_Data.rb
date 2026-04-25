#===============================================================================
# Data handling. DO NOT EDIT
#===============================================================================
class SocialLinkProfile
    attr_accessor :id
    attr_accessor :name
    attr_accessor :image
    attr_accessor :current_location
    attr_accessor :current_status
    attr_accessor :past_statuses
    attr_accessor :bond
    attr_accessor :moments
    attr_accessor :favorite_pokemon
    attr_accessor :im_contact_id
    attr_accessor :time_added
    attr_accessor :favorite


    def initialize(id)
		data = GameData::SocialLinkProfile.get(id)
        @id = data.id
        @name = data.name
        @image = data.image
        @bond = data.init_bond
        @moments = 0
        @current_location = data.init_location
        @current_status = data.init_status
        @past_statuses = []
        @favorite_pokemon = data.favorite_pokemon
        @im_contact_id = data.im_contact_id
        @time_added = pbGetTimeNow
        @favorite = false
    end

    def current_status
        return _INTL("<i>{1} hasn't posted a recent status.</i>", @name) if @current_status.empty?
        return @current_status
    end

    def toggle_favorite(val = nil)
        @favorite = val unless val.nil?
        @favorite = !@favorite
    end

    def bond_max
        return GameData::SocialLinkProfile.get(@id).bond_max || SocialLinkSettings::BOND_LEVEL_MAX
    end

    def bond_icon_coords
        return GameData::SocialLinkProfile.get(@id).bond_icon_coords
    end

    def moments_max
        max = GameData::SocialLinkProfile.get(@id).moments_max || SocialLinkSettings::MOMENTS_COUNT_MAX
        if max.is_a?(Array)
            return max[@bond] if max[@bond]
            return max[-1]
        else
            return max
        end
    end

end

module GameData
	class SocialLinkProfile
		attr_reader :id
		attr_reader :name
		attr_reader :image
		attr_reader :init_bond
		attr_reader :init_location
		attr_reader :init_status
		attr_reader :favorite_pokemon
        attr_reader :im_contact_id
        attr_reader :static_status_pool
        attr_reader :random_status_pool
        attr_reader :bond_effects
        attr_reader :bond_max
        attr_reader :bond_icon_coords
        attr_reader :moments_max
        attr_reader :free_market_data
		
		DATA = {}

		extend ClassMethodsSymbols
		include InstanceMethods

		def self.load; end
		def self.save; end

		def initialize(hash)
			@id           	    = hash[:id]
			@name    	        = hash[:name] || "???"
			@image    	        = hash[:image] || "default"
			@init_bond 	        = hash[:init_bond] || 0
			@init_location 	    = hash[:init_location] || "???"
			@init_status     	= hash[:init_status] || ""
			@favorite_pokemon 	= hash[:favorite_pokemon] || nil
			@im_contact_id 	    = hash[:im_contact_id] || nil
			@static_status_pool = hash[:static_status_pool] || []
			@random_status_pool = hash[:random_status_pool] || []
			@bond_effects 	    = hash[:bond_effects] || {}
			@bond_max 	        = hash[:bond_max] || SocialLinkSettings::BOND_LEVEL_MAX
			@bond_icon_coords   = hash[:bond_icon_coords] || nil
			@moments_max 	    = hash[:moments_max] || SocialLinkSettings::MOMENTS_COUNT_MAX
            @free_market_data   = {
                :buyer_bond_req     => hash[:buyer_bond_req] || nil,
                :cant_buy_lots      => hash[:cant_buy_lots] || nil,
                :can_buy_condition  => hash[:can_buy_condition] || nil,
                :currency_budgets   => hash[:currency_budgets] || nil,
                :only_use_budgets   => hash[:only_use_budgets] || nil,
                :preferred_items    => hash[:preferred_items] || nil,
                :unpreferred_items  => hash[:unpreferred_items] || nil,
                :preferred_price_range      => hash[:preferred_price_range] || nil,
                :unpreferred_price_range    => hash[:unpreferred_price_range] || nil,
                :score_adjustment   => hash[:score_adjustment] || nil,
                :buyer_personality  => hash[:buyer_personality] || nil,
                :after_purchase     => hash[:after_purchase] || nil
            }
		end
	end

end

