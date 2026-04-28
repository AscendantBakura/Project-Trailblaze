#====================================================================================
#  DO NOT MAKE EDITS HERE
#====================================================================================
module GameData
	class ContestTrainer
		attr_reader :id
		attr_reader :real_name
		attr_reader :character_sprite
		attr_reader :trainer_sprite
		attr_reader :contest_category
		attr_reader :contest_rank
		attr_reader :difficulty
		attr_accessor :pokemon
		attr_reader :pokemon_species
		attr_reader :pokemon_nickname
		attr_reader :pokemon_stat_val
		attr_reader :pokemon_sheen_val
		attr_reader :pokemon_moves
		attr_reader :pokemon_item
		attr_reader :pokemon_shiny
		attr_reader :pokemon_form
		
		DATA = {}

		extend ClassMethodsSymbols
		include InstanceMethods

		def self.load; end
		def self.save; end

		def initialize(hash)
			@id        			= hash[:id]
			@contest_category 	= hash[:contest_category]
			@contest_rank 		= hash[:contest_rank]
			@difficulty 		= hash[:difficulty] || ContestSettings::DEFAULT_TRAINER_DIFFICULTY[["Normal","Super","Hyper","Master"].find_index(@contest_rank)]
			@pokemon_species 	= hash[:pokemon_species]
			@pokemon_stat_val 	= hash[:pokemon_stat_val]
			@pokemon_sheen_val 	= hash[:pokemon_sheen_val]
			@pokemon_moves 		= hash[:pokemon_moves]
			@pokemon_item		= hash[:pokemon_item] || nil
			@pokemon_shiny		= hash[:pokemon_shiny] || false
			@pokemon_form 		= hash[:pokemon_form] || nil
			@real_name 			= hash[:name] || "Unnamed"
			@character_sprite 	= hash[:character_sprite] || nil
			@trainer_sprite		= hash[:trainer_sprite] || nil
			@pokemon_nickname 	= hash[:pokemon_nickname] || GameData::Species.get(@pokemon_species).real_name
			@pokemon			= hash[:pokemon] || nil
		end

		def name
			return _INTL(@real_name)
		end

		def pokemon_name
			return _INTL(@pokemon_nickname)
		end
		
		def species
			return @pokemon_species
		end
		
		def moves
			return @pokemon_moves
		end
		
		def pokemon_stat_val (category=0)
			if @pokemon_stat_val.is_a?(Array)
				@pokemon_stat_val[category]
			else
				return @pokemon_stat_val
			end
		end
	
		def contest_category
			return [@contest_category] if !@contest_category.is_a?(Array)
			return @contest_category
		end
		
		def difficulty
			return @difficulty || 0
		end
	end
end