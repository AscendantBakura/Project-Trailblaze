#====================================================================================
#  DO NOT MAKE EDITS HERE
#====================================================================================
module GameData
	class Move
		attr_accessor :contest_type
		attr_accessor :contest_hearts
		attr_accessor :contest_jam
		attr_accessor :contest_function_code
		attr_accessor :contest_flags
		attr_accessor :contest_description

		CONTEST_SCHEMA = {
		  "ContestType"         => [:contest_type,     				"E", :ContestType],
		  "ContestHearts"       => [:contest_hearts,   				"U"],
		  "ContestJam"     			=> [:contest_jam,      				"U"],
		  "ContestFunctionCode" => [:contest_function_code,		"E", :ContestMoveFunction],
		  "ContestFlags"        => [:contest_flags,         	"*s"],
		  "ContestDescription"  => [:contest_description,   	"q"],
		}


		extend ClassMethodsSymbols
		include InstanceMethods


		# @return [String] the translated description of this move



		def contest_description(compile = false)
			return getFunctionContestDescription if !compile && ContestSettings::GET_MOVE_DESCRIPTIONS_FROM_FUNCTION
			return _INTL("Cannot be used in a contest.") if !compile && !contest_can_be_used?
			return pbGetMessageFromHash(MessageTypes::MoveContestDescriptions, @contest_description)
		end

		def has_contest_flag?(flag)
		return false if !@contest_flags || @contest_flags.empty?
		return @contest_flags.any? { |f| f == flag }
		end
	
		alias contests_hasflag has_flag?
		def has_flag?(flag)
			ret = contests_hasflag(flag)
			return ret || has_contest_flag?(flag)
		end
		
		def contest_type_position
			return 5 if !contest_can_be_used?
			return GameData::ContestType.get(@contest_type).icon_index || 0
		end	
		
		def startsContestCombo
			return ContestSettings::COMBOS.include?(self.id)
			return false
		end
		
		def contest_can_be_used?
			return false if (has_contest_flag?("CannotBeUsed") || @contest_function_code.nil?)
			return true
		end
		
		def is_positive_category?(contestCategory)
			return contest_type_position == contestCategory
		end
	
		def is_neutral_category?(contestCategory)
			case contestCategory
			when 0
				return [4,1].include?(contest_type_position)
			when 1
				return [0,2].include?(contest_type_position)
			when 2
				return [1,3].include?(contest_type_position)
			when 3
				return [2,4].include?(contest_type_position)
			when 4
				return [3,0].include?(contest_type_position)
			end
			return false
		end
	
		def is_negative_category?(contestCategory)
			case contestCategory
			when 0
				return [3,2].include?(contest_type_position)
			when 1
				return [4,3].include?(contest_type_position)
			when 2
				return [0,4].include?(contest_type_position)
			when 3
				return [1,0].include?(contest_type_position)
			when 4
				return [2,1].include?(contest_type_position)
			end
			return false
		end
	end
end