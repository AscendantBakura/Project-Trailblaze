# Versioned PBS parser shared by the engine and the restoration installer.
module PMDDungeon
  module DataStore
    VERSION = 1
    FILES = %w[pmd_global pmd_dungeons pmd_tilesets pmd_traps pmd_companions]
    ID_PATTERN = /\A[A-Za-z][A-Za-z0-9_]*\z/
    ROWS = %w[FloorCardBackground StatusImmunity Tile Autotile Pokemon TalkMessage FlavourMessage FloorSetting FloorMap Wild WildRate MaxEventsOnFloor Item ItemGraphic ForcedItem TrapWeight ForcedTrap NPC NPCText NPCHeals Trainer TrainerName TrainerSpecies TrainerPokemon SmugglerItem Criminal CriminalBribe CriminalText TreasureTier TreasureItem Bounty BountyDescription BountyPokemon Milestone MilestoneText]
    GLOBAL = {
      "FormatVersion"=>"positive", "EventTemplateMap"=>"positive", "EventTemplate"=>"positive", "ItemTemplate"=>"positive", "TrapTemplate"=>"positive",
      "FloorVariable"=>"natural", "BankVariable"=>"positive", "LawVariable"=>"positive", "ChaosVariable"=>"positive", "AllyFollowerName"=>"text", "DebugMenu"=>"bool",
      "FloorCardFrames"=>"natural", "DefaultTitle"=>"text", "MinimapIcon"=>"text", "MinimapSmallSize"=>"positive", "MinimapFullSize"=>"positive",
      "FloorCardBackground"=>"enum:morning|afternoon|evening|night text", "StatusImmunity"=>"id *id"
    }
    GENERATION = {
      "DungeonSize"=>"positive positive", "CellSize"=>"positive positive", "MinRoomSize"=>"positive positive", "MaxRoomSize"=>"positive positive",
      "CorridorWidth"=>"positive", "ShiftCorridors"=>"bool", "NodeLayout"=>"enum:full|no_corners|ring|antiring|plus|diagonal_up|diagonal_down|cross|quadrants",
      "RoomLayout"=>"enum:legacy_random|full|no_corners|ring|antiring|plus|diagonal_up|diagonal_down|cross|quadrants", "RoomChance"=>"percent", "ExtraConnections"=>"natural",
      "FloorPatches"=>"natural percent percent", "FloorDecorations"=>"natural natural", "VoidDecorations"=>"natural natural", "GrassPatchFactor"=>"number"
    }
    DUNGEON = GENERATION.merge({
      "Inherit"=>"enum:DEFAULT", "Name"=>"text", "MapIDs"=>"*positive", "EntryMaps"=>"*positive", "EntryMode"=>"enum:caller|fixed", "EntryDestination"=>"positive natural natural direction",
      "StartFloor"=>"positive", "FloorLimit"=>"natural", "ExitMode"=>"enum:entrance|fixed", "ExitDestination"=>"positive natural natural direction",
      "FloorMap"=>"floor positive", "Tileset"=>"id", "ParametersArea"=>"id", "ParametersVersion"=>"natural", "FloorSetting"=>"floor text *text",
      "WildMode"=>"enum:map|table|none", "EncounterMap"=>"positive", "Wild"=>"floor id id weight positive positive", "WildRate"=>"id natural",
      "WildLevel"=>"integer integer positive positive", "WildLevelMode"=>"enum:range|floor", "MaxEvents"=>"natural", "MaxEventsOnFloor"=>"floor natural",
      "EventWeights"=>"number number number", "Item"=>"id floor weight id bool natural natural natural", "ItemGraphic"=>"id text direction pattern",
      "ForcedItem"=>"floor id positive", "ExtraItemCount"=>"natural natural", "Traps"=>"*id", "TrapWeight"=>"id floor weight", "ForcedTrap"=>"floor id", "ExtraTrapCount"=>"natural natural",
      "NPC"=>"id enum:outlaw|nurse|quest floor probability text bool natural id id weight", "NPCText"=>"id text text", "NPCHeals"=>"id natural", "NPCItemPool"=>"*id",
      "TrainerChance"=>"probability", "TrainerMinFloor"=>"positive", "TrainerSight"=>"positive", "TrainerPartyMode"=>"enum:random|fixed|pbs", "TrainerPartySize"=>"positive positive positive",
      "TrainerLevelBonus"=>"integer", "TrainerMoneyMode"=>"enum:trainer_type|fixed", "TrainerMoneyBase"=>"natural", "Trainer"=>"id id text weight floor natural",
      "TrainerName"=>"id text", "TrainerSpecies"=>"id weight", "TrainerPokemon"=>"id id natural",
      "SmugglerChance"=>"probability", "SmugglerMinFloor"=>"positive", "SmugglerGraphic"=>"text", "SmugglerPriceMultiplier"=>"number", "SmugglerStockSize"=>"natural",
      "SmugglerStockScope"=>"enum:floor|run", "SmugglerShopArt"=>"text", "SmugglerItem"=>"id positive natural weight floor",
      "CriminalChance"=>"probability", "CriminalMinFloor"=>"positive", "CriminalSpeed"=>"speed", "CriminalFrequency"=>"speed", "CriminalBehaviour"=>"enum:flee|stationary",
      "CriminalAccept"=>"enum:keep|remove", "CriminalRefuse"=>"enum:arrest|keep", "CriminalAuraStep"=>"natural", "Criminal"=>"id text text id weight floor",
      "CriminalBribe"=>"id weight positive floor", "CriminalText"=>"text text", "TreasureChance"=>"probability", "TreasureCount"=>"natural natural", "TreasureRadius"=>"natural",
      "TreasureTier"=>"id text weight floor", "TreasureItem"=>"id id weight positive floor", "Bounty"=>"id enum:find|defeat text floor text natural id natural id text positive integer",
      "BountyDescription"=>"id text", "BountyPokemon"=>"id id natural", "BountySealEntrances"=>"bool", "BountySealGraphic"=>"text", "Milestone"=>"id positive enum:teleport_away|rest_area|end_of_area|boss natural natural natural direction id natural",
      "MilestoneText"=>"id enum:message|before|win text", "ItemRestriction"=>"enum:none|store_all", "ItemAllowed"=>"*id", "DefeatMoneyFraction"=>"probability", "DefeatDestination"=>"positive natural natural direction", "HiddenOpacity"=>"opacity",
      "BGM"=>"text", "WildBattleBGM"=>"text", "TrainerBattleBGM"=>"text", "WildVictoryBGM"=>"text", "TrainerVictoryBGM"=>"text", "BGMVolume"=>"percent", "BGMPitch"=>"pitch"
    })
    %w[Foe Hunter].each do |prefix|
      {"Enabled"=>"bool", "Graphic"=>"text", "Speed"=>"speed", "Species"=>"*id", "RaidStyle"=>"id", "RaidRank"=>"positive", "LevelBonus"=>"integer", "TurnCount"=>"positive", "KOCount"=>"positive", "ShieldHP"=>"natural", "ExtraActions"=>"*id"}.each { |k,v| DUNGEON[prefix+k]=v }
    end
    {"FoeStartDepth"=>"positive", "FoeClimbSteps"=>"positive", "HunterMinFloor"=>"positive", "HunterSpawnSeconds"=>"positive", "HunterName"=>"text", "FoeStartFloor"=>"positive", "FoeResetFloor"=>"positive", "HunterSpawnSteps"=>"positive", "HunterType"=>"id"}.each { |k,v| DUNGEON[k]=v }
    TILESET = {"Tileset"=>"positive", "Tile"=>"natural id", "Autotile"=>"slot id", "ThinNorthWallOffset"=>"integer", "Flags"=>"*text", "StairsDown"=>"positive", "StairsUp"=>"positive", "LadderTop"=>"natural", "HidingTiles"=>"*floor", "HidingTerrainTags"=>"*natural"}
    %w[SnapToLargeGrid LargeVoidTiles LargeWallTiles LargeFloorTiles DoubleWalls FloorPatchUnderWalls].each { |k| TILESET[k]="bool" }
    TRAP = {"Type"=>"enum:status|explosion|pp_down|spikes|teleport_room|floor_shift|miniboss", "Floors"=>"floor", "Weight"=>"weight", "Graphic"=>"text", "Message"=>"text", "Disappears"=>"bool", "FailChance"=>"probability", "Status"=>"id", "DamageFraction"=>"probability", "DampBlocked"=>"bool", "PPFraction"=>"probability", "IgnoreRaised"=>"bool", "TeleportDistance"=>"positive", "Direction"=>"enum:up|down", "Species"=>"id", "Level"=>"positive"}
    COMPANION = {"TrainerType"=>"id", "TrainerName"=>"text", "TrainerVersion"=>"natural", "Graphic"=>"text", "PartyMode"=>"enum:generated|pbs", "Pokemon"=>"id natural", "MinLevel"=>"positive", "LevelOffset"=>"integer", "PartnerScope"=>"enum:dungeon", "FlavourMessage"=>"text", "TalkMessage"=>"text", "FlavourChance"=>"probability", "FlavourCooldown"=>"natural"}
    %w[AskMessage ConfirmMessage AcceptChoice DeclineChoice AcceptMessage DeclineMessage AlreadyFollowingMessage DungeonRecruitMessage KeepChoice TeamChoice DismissChoice KeepMessage DismissConfirm DismissAcceptChoice DismissDeclineChoice DismissMessage DismissCancelMessage].each { |k| COMPANION[k]="text" }
    SCHEMAS = [GLOBAL,DUNGEON,TILESET,TRAP,COMPANION]
    BUILTIN_DUNGEON = {"EntryMode" => :caller, "StartFloor" => 1, "FloorLimit" => 0, "ExitMode" => :entrance, "ParametersArea" => :tower, "ParametersVersion" => 0, "DungeonSize" => [4, 4], "CellSize" => [10, 10], "MinRoomSize" => [5, 5], "MaxRoomSize" => [9, 9], "CorridorWidth" => 2, "ShiftCorridors" => false, "NodeLayout" => :full, "RoomLayout" => :legacy_random, "RoomChance" => 70, "ExtraConnections" => 2, "FloorPatches" => [3, 75, 25], "FloorDecorations" => [50, 200], "VoidDecorations" => [50, 200], "GrassPatchFactor" => 0.35, "WildMode" => :map, "WildLevel" => [4, 2, 1, 100], "WildLevelMode" => :range, "MaxEvents" => 4, "EventWeights" => [0.4, 0.3, 0.3], "ExtraItemCount" => [0, 0], "ExtraTrapCount" => [0, 0], "TrainerChance" => 0.45, "TrainerMinFloor" => 1, "TrainerSight" => 4, "TrainerPartyMode" => :random, "TrainerPartySize" => [1, 3, 3], "TrainerLevelBonus" => 0, "TrainerMoneyMode" => :trainer_type, "TrainerMoneyBase" => 40, "SmugglerChance" => 0.25, "SmugglerMinFloor" => 2, "SmugglerGraphic" => "NPC Unova Punk", "SmugglerPriceMultiplier" => 2.5, "SmugglerStockSize" => 4, "SmugglerStockScope" => :floor, "SmugglerShopArt" => "Graphics/UI/overlayUI/Shop Sprite", "CriminalChance" => 0.3, "CriminalMinFloor" => 1, "CriminalSpeed" => 4, "CriminalFrequency" => 5, "CriminalBehaviour" => :flee, "CriminalAccept" => :keep, "CriminalRefuse" => :arrest, "CriminalAuraStep" => 1, "TreasureChance" => 0.3, "TreasureCount" => [1, 3], "TreasureRadius" => 2, "ItemRestriction" => :none, "DefeatMoneyFraction" => 0.5, "DefeatDestination" => [102, 17, 10, 6], "BountySealEntrances" => true, "BountySealGraphic" => "Object boulder", "HiddenOpacity" => 128, "FoeEnabled" => true, "FoeStartDepth" => 10, "FoeClimbSteps" => 300, "FoeGraphic" => "auto", "FoeSpeed" => 4, "HunterEnabled" => true, "HunterMinFloor" => 2, "HunterSpawnSeconds" => 180, "HunterGraphic" => "auto", "HunterName" => "Hunter", "HunterSpeed" => 4, "FoeSpecies" => [:GENGAR], "FoeRaidStyle" => :Basic, "FoeRaidRank" => 4, "FoeLevelBonus" => 8, "FoeTurnCount" => 8, "FoeKOCount" => 3, "FoeShieldHP" => 6, "FoeExtraActions" => [:reset_drops, :reset_boosts], "HunterSpecies" => [:MIGHTYENA, :HOUNDOOM, :SNEASEL], "HunterRaidStyle" => :Basic, "HunterRaidRank" => 2, "HunterLevelBonus" => 3, "HunterTurnCount" => 12, "HunterKOCount" => 5, "HunterShieldHP" => 3, "HunterExtraActions" => [], "EntryMaps" => [], "FloorSetting" => [], "MaxEventsOnFloor" => [], "ForcedItem" => [], "ForcedTrap" => [], "TrapWeight" => [], "TrainerPokemon" => [], "BountyPokemon" => [], "Milestone" => [], "MilestoneText" => [], "ItemAllowed" => [], "BGM" => nil, "WildBattleBGM" => nil, "TrainerBattleBGM" => nil, "WildVictoryBGM" => nil, "TrainerVictoryBGM" => nil, "TrainerSpecies" => [[:PIDGEY, 1.0], [:RATTATA, 1.0], [:SENTRET, 1.0], [:HOOTHOOT, 1.0], [:ZIGZAGOON, 1.0], [:LILLIPUP, 1.0], [:PATRAT, 1.0], [:BIDOOF, 1.0], [:STARLY, 1.0], [:WURMPLE, 1.0], [:CATERPIE, 1.0], [:WEEDLE, 1.0]], "Trainer" => [[:HIKER, :HIKER, "trainer_HIKER", 1.0, [1, nil], 0], [:BLACKBELT, :BLACKBELT, "trainer_BLACKBELT", 1.0, [1, nil], 0], [:BEAUTY, :BEAUTY, "trainer_BEAUTY", 1.0, [1, nil], 0], [:PSYCHIC_M, :PSYCHIC_M, "trainer_PSYCHIC_M", 1.0, [1, nil], 0], [:PSYCHIC_F, :PSYCHIC_F, "trainer_PSYCHIC_F", 1.0, [1, nil], 0]], "TrainerName" => [[:HIKER, "Marcos"], [:HIKER, "Russell"], [:HIKER, "Anthony"], [:BLACKBELT, "Kenji"], [:BLACKBELT, "Ricky"], [:BLACKBELT, "Nob"], [:BEAUTY, "Bridget"], [:BEAUTY, "Olivia"], [:BEAUTY, "Lola"], [:PSYCHIC_M, "Fidel"], [:PSYCHIC_M, "Jaylen"], [:PSYCHIC_M, "Rodette"], [:PSYCHIC_F, "Alexis"], [:PSYCHIC_F, "Rachel"], [:PSYCHIC_F, "Mariah"]], "ItemGraphic" => [[:common, "Dungeon Chest Common", 8, 0], [:uncommon, "Dungeon Chest Uncommon", 8, 0], [:rare, "Dungeon Chest Rare", 8, 0], [:sr, "Dungeon Chest SR", 8, 0]], "Item" => [[:POTION, [1, 999], 20.0, :common, false, 0, 0, 0], [:ANTIDOTE, [1, 999], 8.0, :common, false, 0, 0, 0], [:AWAKENING, [1, 999], 8.0, :common, false, 0, 0, 0], [:PARALYZEHEAL, [1, 999], 8.0, :common, false, 0, 0, 0], [:SUPERPOTION, [5, 999], 12.0, :uncommon, false, 0, 0, 0], [:SITRUSBERRY, [1, 999], 10.0, :uncommon, false, 0, 0, 0], [:POKEBALL, [1, 999], 15.0, :common, false, 0, 0, 0], [:GREATBALL, [1, 999], 8.0, :uncommon, false, 0, 0, 0], [:REVIVE, [1, 999], 3.0, :rare, false, 0, 0, 0], [:FULLRESTORE, [1, 999], 2.0, :sr, true, 0, 0, 0]], "Traps" => [:BURN_TRAP, :HYPNOSIS_TRAP, :VOLTORB, :SPIKE_FIELD, :PP_DRAIN, :PARALYZE_TRAP, :POISON_TRAP], "NPCHeals" => [], "NPCItemPool" => [:POTION, :SUPERPOTION, :POKEBALL, :GREATBALL, :ANTIDOTE, :AWAKENING, :PARALYZEHEAL, :SITRUSBERRY], "NPC" => [[:OUTLAW, :outlaw, [1, 999], 0.2, "NPC Outlaw", false, 0, :none, :none, 1.0], [:NURSE, :nurse, [1, 999], 0.35, "NPC 16", false, 1, :none, :none, 1.0], [:MERCHANT, :quest, [1, 999], 0.15, "NPC 17", false, 0, :POKEBALL, :POTION, 1.0]], "NPCText" => [[:OUTLAW, "caught", "Now hold on."], [:OUTLAW, "turned_in", "Things were a lot simpler when I was robbing banks with the Deadlock Gang"], [:OUTLAW, "after_bribe", "Thanks. Put it on my tab. "], [:OUTLAW, "repeat", "'Gunslinger' never made sense to me. I don't sling guns; I sling bullets. "], [:NURSE, "before", "You and your Pokemon have come a long way. Let me heal your team."], [:NURSE, "after", "All better! Take care as you explore."], [:NURSE, "exhausted", "I'm out of healing supplies. Take care on your journey!"], [:MERCHANT, "no_item", "Pokéball ?"], [:MERCHANT, "have_item", "Gimme"], [:MERCHANT, "reward", "Thamks."]], "SmugglerItem" => [[:POTION, 3, 0, 1.0, [1, nil]], [:SUPERPOTION, 2, 0, 1.0, [1, nil]], [:ANTIDOTE, 2, 0, 1.0, [1, nil]], [:PARALYZEHEAL, 2, 0, 1.0, [1, nil]], [:AWAKENING, 2, 0, 1.0, [1, nil]], [:ESCAPEROPE, 1, 0, 1.0, [1, nil]], [:POKEBALL, 5, 0, 1.0, [1, nil]], [:GREATBALL, 2, 0, 1.0, [1, nil]], [:REVIVE, 1, 0, 1.0, [1, nil]], [:ETHER, 1, 0, 1.0, [1, nil]]], "Criminal" => [[:CRIMINAL_1, "Pickpocket", "HGSS Burglar (Overworld)", :HOOLIGANS, 1.0, [1, nil]], [:CRIMINAL_2, "Smuggler's Runner", "NPC Unova Punk", :BIKER, 1.0, [1, nil]]], "CriminalBribe" => [[:NUGGET, 1.0, 1, [1, nil]], [:PEARL, 1.0, 1, [1, nil]], [:STARDUST, 1.0, 1, [1, nil]], [:BIGPEARL, 1.0, 1, [1, nil]], [:RARECANDY, 1.0, 1, [1, nil]]], "CriminalText" => [["caught", "{1}: Whoa, whoa! No need to make a scene..."], ["offer", "Take this {1} and forget you ever saw me?"], ["accept_choice", "Accept"], ["refuse_choice", "Refuse"], ["accepted", "{1}: Pleasure doing business. I was never here."], ["repeat", "{1}: We had a deal, remember? You never saw me."], ["refused", "You refused the bribe and signalled the park rangers."], ["arrested", "{1} was arrested!"]], "TreasureTier" => [[:common, "Dungeon Chest Common", 60.0, [1, nil]], [:uncommon, "Dungeon Chest Uncommon", 25.0, [1, nil]], [:rare, "Dungeon Chest Rare", 12.0, [1, nil]], [:sr, "Dungeon Chest SR", 3.0, [1, nil]]], "TreasureItem" => [[:common, :POTION, 1.0, 1, [1, nil]], [:common, :ANTIDOTE, 1.0, 1, [1, nil]], [:common, :POKEBALL, 1.0, 1, [1, nil]], [:common, :ORANBERRY, 1.0, 1, [1, nil]], [:uncommon, :SUPERPOTION, 1.0, 1, [1, nil]], [:uncommon, :GREATBALL, 1.0, 1, [1, nil]], [:uncommon, :ETHER, 1.0, 1, [1, nil]], [:rare, :HYPERPOTION, 1.0, 1, [1, nil]], [:rare, :ULTRABALL, 1.0, 1, [1, nil]], [:rare, :REVIVE, 1.0, 1, [1, nil]], [:sr, :MAXREVIVE, 1.0, 1, [1, nil]], [:sr, :RARECANDY, 1.0, 1, [1, nil]], [:sr, :PPUP, 1.0, 1, [1, nil]]], "Bounty" => [[:LOST_SATCHEL, :find, "Lost Satchel", [2, 4], "Dungeon Chest Common", 600, :SUPERPOTION, 1, :none, "", 2, 3], [:PARK_BULLY, :defeat, "Park Bully", [3, 6], "NPC Outlaw", 1200, :GREATBALL, 1, :HOOLIGANS, "Bully", 2, 3]], "BountyDescription" => [[:LOST_SATCHEL, "A hiker dropped a satchel in Beginner Park."], [:PARK_BULLY, "Someone is picking fights deep in Beginner Park."]]}
    BUILTIN_GLOBAL = {"FormatVersion" => 1, "EventTemplateMap" => 113, "EventTemplate" => 1, "ItemTemplate" => 2, "TrapTemplate" => 4, "FloorVariable" => 0, "BankVariable" => 149, "LawVariable" => 19, "ChaosVariable" => 20, "AllyFollowerName" => "PMDAlly", "DebugMenu" => true, "FloorCardFrames" => 60, "DefaultTitle" => "Dungeon", "MinimapIcon" => "Graphics/UI/overlayUI/iconsOverlayBig", "MinimapSmallSize" => 12, "MinimapFullSize" => 18, "FloorCardBackground" => [[:morning, "Graphics/UI/Day-Transition.gif"], [:afternoon, "Graphics/UI/Afternoon-Transition.gif"], [:evening, "Graphics/UI/Evening-Transition.gif"], [:night, "Graphics/UI/Night-Transition.gif"]], "StatusImmunity" => [[:BURN, :FIRE], [:POISON, :POISON, :STEEL], [:PARALYSIS, :ELECTRIC], [:FROZEN, :ICE], [:FROSTBITE, :ICE], [:SLEEP]]}
    class Error < StandardError; end
    class << self
      attr_accessor :bundle, :context_map
    end
    module_function

    def fields(text)
      result=[]; i=0
      loop do
        i+=1 while text[i] && text[i] =~ /\s/
        break if !text[i] || text[i]=='#'
        field=String.new
        if text[i]=='"'
          i+=1; closed=false
          while text[i]
            ch=text[i]; i+=1
            if ch=='"'; closed=true; break; end
            if ch=='\\'
              raise Error, "unterminated escape" if !text[i]
              ch=text[i]; i+=1
            end
            field << ch
          end
          raise Error, "unterminated quoted field" if !closed
          i+=1 while text[i] && text[i] =~ /\s/
          raise Error, "expected comma after quoted field" if text[i] && text[i]!=',' && text[i]!='#'
        else
          while text[i] && text[i]!=',' && text[i]!='#'; field << text[i]; i+=1; end
          field=field.strip
          raise Error, "quote in unquoted field" if field.include?('"')
        end
        result << field
        break if !text[i] || text[i]=='#'
        i+=1
        if !text[i] || text[i..-1].strip.empty?; result << ""; break; end
      end
      result
    end

    def convert(value,type)
      return value if type=="text"
      if type.start_with?("enum:")
        raise Error,"expected #{type[5..-1]}" unless type[5..-1].split('|').include?(value)
        return value.to_sym
      end
      if type=="id"
        raise Error,"invalid PBS ID #{value.inspect}" unless value =~ ID_PATTERN
        return value.to_sym
      end
      if type=="bool"
        raise Error,"expected true or false" unless %w[true false].include?(value)
        return value=="true"
      end
      if type=="floor"
        match=/\A(\d+)(?:\.\.(\d+|\*))?\z/.match(value)
        raise Error,"invalid floor range #{value.inspect}" if !match || match[1].to_i<1
        first=match[1].to_i; last=match[2]=='*' ? nil : (match[2] || match[1]).to_i
        raise Error,"reversed floor range" if last && last<first
        return [first,last]
      end
      if %w[number weight probability].include?(type)
        raise Error,"expected finite decimal" unless value =~ /\A-?\d+(?:\.\d+)?\z/
        n=value.to_f
        raise Error,"number out of range" if !n.finite? || n<0 || (type=="weight" && n<=0) || (type=="probability" && n>1)
        return n
      end
      raise Error,"expected integer" unless value =~ /\A-?\d+\z/
      n=value.to_i
      bounds={"positive"=>[1,nil],"natural"=>[0,nil],"percent"=>[0,100],"direction"=>[2,8],"pattern"=>[0,3],"speed"=>[1,6],"slot"=>[1,7],"opacity"=>[0,255],"pitch"=>[50,150]}
      if bounds[type]
        lo,hi=bounds[type]; raise Error,"integer out of range" if n<lo || hi && n>hi
      end
      raise Error,"direction must be 2,4,6,8" if type=="direction" && ![2,4,6,8].include?(n)
      n
    end

    def tuple(values,schema)
      types=schema.split; star=types.last && types.last.start_with?('*')
      required=types.length-(star ? 1 : 0)
      raise Error,"expected #{schema}, got #{values.length} fields" if values.length<required || !star && values.length!=required
      values.each_with_index.map { |v,i| convert(v,(types[i] || types.last).delete_prefix('*')) }
    end

    def parse(text,schema,file)
      result={}; section=nil
      text=text.dup.force_encoding('UTF-8').sub(/\A\uFEFF/, '')
      raise Error,"#{file}: invalid UTF-8" if !text.valid_encoding?
      text.each_line.with_index(1) do |line,num|
        begin
          next if line.strip.empty? || line.lstrip.start_with?('#')
          if line =~ /\A\s*\[([^\]]+)\]\s*(?:#.*)?\s*\z/
            section=$1
            raise Error,"invalid section ID" unless section.split('@',-1).all? { |s| s =~ ID_PATTERN } && section.count('@')<=1
            raise Error,"duplicate section" if result[section.to_sym]
            result[section.to_sym]={}; next
          end
          raise Error,"property before section" if !section
          match=/\A\s*(\w+)\s*=\s*(.*?)\s*\z/.match(line)
          raise Error,"expected Key = value" unless match
          key=match[1]; raw=fields(match[2]); data=result[section.to_sym]
          raise Error,"unknown key #{key}" unless schema[key]
          raise Error,"invalid companion override key #{key}" if section.include?('@') && !%w[FlavourMessage FlavourChance FlavourCooldown].include?(key)
          if key=="NPC" && !raw.empty? && raw.length>=5 && raw.length<10
            raw += %w[false 0 none none 1][(raw.length-5)..-1]
          end
          value=raw.empty? ? [] : tuple(raw,schema[key])
          if ROWS.include?(key) && !(schema.equal?(COMPANION) && key=="TrainerName")
            raise Error,"clear mixed with rows for #{key}" if data.key?(key) && (data[key].empty? || value.empty?)
            (data[key]||=[]) << value unless value.empty?
            data[key]||=[]
          else
            raise Error,"duplicate #{key}" if data.key?(key)
            if value.empty? && !schema[key].start_with?('*') && schema[key]!="text" && !%w[Tileset EntryDestination ExitDestination EncounterMap].include?(key)
              raise Error,"#{key} cannot be empty"
            end
            data[key]=schema[key].start_with?('*') || schema[key].split.length>1 ? value : value[0]
          end
        rescue Error => ex
          raise Error,"#{file}:#{num} [#{section}] #{ex.message}"
        end
      end
      result
    end

    def covers?(range,floor)
      range && floor>=range[0] && (!range[1] || floor<=range[1])
    end

    def rows(data,key)
      data[key] || []
    end

    def compile_sources(sources, validator=nil)
      data={}
      FILES.each_with_index do |file,index|
        raise Error,"missing PBS/#{file}.txt" unless sources[file]
        data[file]=parse(sources[file],SCHEMAS[index],file+'.txt')
      end
      raise Error,"pmd_global.txt: expected only GLOBAL" unless data['pmd_global'].keys==[:GLOBAL]
      raise Error,"unsupported FormatVersion" unless data['pmd_global'][:GLOBAL]['FormatVersion']==VERSION
      defaults=Marshal.load(Marshal.dump(BUILTIN_DUNGEON)).merge(data['pmd_dungeons'].delete(:DEFAULT) || {})
      identity=%w[Name MapIDs EntryMaps EntryDestination ExitDestination FloorMap Tileset EncounterMap WildRate Wild]
      inherited=defaults.reject { |key,_value| identity.include?(key) }
      data['pmd_global'][:GLOBAL]=Marshal.load(Marshal.dump(BUILTIN_GLOBAL)).merge(data['pmd_global'][:GLOBAL])
      data['pmd_dungeons'].transform_values! { |d| Marshal.load(Marshal.dump(inherited)).merge(d) }
      data['defaults']=defaults
      validate(data,validator)
      data
    end

    def compile_directory(root,validator=nil)
      compile_sources(FILES.to_h { |f| [f, File.file?(File.join(root,'PBS',f+'.txt')) ? File.binread(File.join(root,'PBS',f+'.txt')) : nil] },validator)
    end

    # Version-independent text form (Hash#inspect changed in Ruby 3.4, and the
    # installer's Ruby differs from the game's).
    def canonical(value)
      case value
      when Hash then '{'+value.map { |k,v| canonical(k)+'=>'+canonical(v) }.join(',')+'}'
      when Array then '['+value.map { |v| canonical(v) }.join(',')+']'
      when String then 's'+value.bytesize.to_s+':'+value.b
      when Symbol then ':'+value.to_s.b
      when Float then 'f'+format('%.17g',value)
      when Integer then 'i'+value.to_s
      else value.class.name+':'+value.to_s.b
      end
    end

    def fingerprint_for(data)
      canonical(data).bytes.inject(0) { |sum,byte| ((sum*31)+byte) & 0x7fffffff }
    end

    def outputs(data)
      fingerprint=fingerprint_for(data)
      FILES.to_h do |name|
        record={version:VERSION,bundle:fingerprint,data:data[name]}
        record[:defaults]=data['defaults'] if name=='pmd_dungeons'
        [File.join('Data',name+'.dat'),Marshal.dump(record)]
      end
    end

    def publish(root,data)
      bytes=outputs(data); originals={}
      bytes.each_key { |rel| path=File.join(root,rel); originals[path]=File.file?(path) ? File.binread(path) : nil }
      begin
        bytes.each { |rel,content| File.binwrite(File.join(root,rel),content) }
      rescue Exception
        originals.each { |path,old| old ? File.binwrite(path,old) : File.delete(path) if old || File.file?(path) }
        raise
      end
      activate(data)
    end

    def activate(data)
      self.bundle=data
      @settings_cache={}
      if defined?(GameData::PMDGlobal)
        FILES.each_with_index do |file,index|
          klass=GameData.const_get(%w[PMDGlobal PMDDungeon PMDTileset PMDTrap PMDCompanion][index])
          klass::DATA.clear
          data[file].each { |id,record| klass.register(id:id,properties:record) }
        end
      end
      data
    end

    def boot(root='.',development=false)
      present=FILES.map { |f| File.file?(File.join(root,'Data',f+'.dat')) }
      sources=FILES.map { |f| File.file?(File.join(root,'PBS',f+'.txt')) }
      if present.any?
        raise Error,'incomplete PMD compiled bundle' unless present.all?
        records=FILES.map { |f| Marshal.load(File.binread(File.join(root,'Data',f+'.dat'))) }
        raise Error,'incompatible or mixed PMD compiled bundle; rebuild all five files' unless records.all? { |r| r.is_a?(Hash) && r[:version]==VERSION && r[:data].is_a?(Hash) } && records.map { |r| r[:bundle] }.uniq.length==1
        data=FILES.each_with_index.to_h { |f,i| [f,records[i][:data]] }; data['defaults']=records[1][:defaults] || {}
        raise Error,'corrupt PMD compiled bundle; rebuild it' unless fingerprint_for(data)==records[0][:bundle]
        validate(data)
        return activate(data)
      end
      if sources.any?
        raise Error,'incomplete PMD PBS set' unless sources.all?
        raise Error,'PMD PBS must be compiled before playing a release build' unless development
        return publish(root,compile_directory(root,method(:native_reference!)))
      end
      self.bundle=nil
      if defined?(GameData::PMDGlobal)
        %w[PMDGlobal PMDDungeon PMDTileset PMDTrap PMDCompanion].each { |name| GameData.const_get(name)::DATA.clear }
      end
      nil
    rescue Error
      raise
    rescue StandardError => ex
      raise Error,"PMD data load failed: #{ex.message}"
    end

    def native_reference!(type,id)
      return if id.nil? || id==:none || id==:random
      klass=GameData.const_get(type)
      exists=type==:Trainer ? klass.exists?(*id) : klass.exists?(id)
      raise Error,"unknown #{type} #{id}" unless exists
    end

    def validate(data,reference=nil)
      reference ||= proc { |_type,_id| }
      ref=proc { |type,id| reference.call(type,id) unless id.nil? || [:none,:random].include?(id) }
      owned={}
      data['pmd_dungeons'].each do |id,d|
        begin
          maps=d['MapIDs']; raise Error,'MapIDs must be nonempty' if !maps || maps.empty?
          maps.each { |m| raise Error,"map #{m} also belongs to #{owned[m]}" if owned[m]; owned[m]=id }
          raise Error,'unknown palette' if d['Tileset'] && !data['pmd_tilesets'][d['Tileset']]
          raise Error,'FloorLimit precedes StartFloor' if d['FloorLimit'].to_i>0 && d['FloorLimit']<(d['StartFloor'] || 1)
          %w[Entry Exit].each { |k| raise Error,"#{k}Destination required" if d[k+'Mode']==:fixed && !d[k+'Destination'] }
          %w[DungeonSize CellSize MinRoomSize MaxRoomSize ExtraItemCount ExtraTrapCount TreasureCount WildLevel].each do |key|
            a=d[key]; next unless a
            if %w[ExtraItemCount ExtraTrapCount TreasureCount].include?(key)
              raise Error,"#{key} reversed bounds" if a[0]>a[1]
            elsif key=='WildLevel'
              raise Error,'WildLevel reversed limits' if a[2]>a[3]
            end
          end
          if d['CellSize'] && d['MinRoomSize'] && d['MaxRoomSize']
            2.times { |i| raise Error,'room does not fit cell' if d['MinRoomSize'][i]>d['MaxRoomSize'][i] || d['MaxRoomSize'][i]>=d['CellSize'][i] || d['CorridorWidth'].to_i>=d['CellSize'][i] }
          end
          raise Error,'TrainerPartySize exceeds six' if d['TrainerPartySize'] && d['TrainerPartySize'][2]>6
          check_ranges(rows(d,'FloorMap').map(&:first),'FloorMap')
          rows(d,'FloorMap').each { |r| raise Error,'FloorMap outside MapIDs' unless maps.include?(r[1]) }
          routes=rows(d,'FloorMap').sort_by { |r| r[0][0] }
          unless routes.empty?
            next_floor=1
            routes.each do |range,_map|
              raise Error,'FloorMap leaves a gap' unless range[0]==next_floor
              next_floor=range[1] ? range[1]+1 : Float::INFINITY
            end
            limit=d['FloorLimit'].to_i
            raise Error,'FloorMap does not cover all floors' if limit==0 && next_floor!=Float::INFINITY || limit>0 && next_floor<=limit
          end
          check_ranges(rows(d,'MaxEventsOnFloor').map(&:first),'MaxEventsOnFloor')
          rows(d,'FloorSetting').group_by { |r| r[1] }.each do |key,rules|
            raise Error,"invalid generation override #{key}" unless GENERATION[key]
            check_ranges(rules.map(&:first),'FloorSetting '+key)
            rules.each { |r| tuple(r[2..-1],GENERATION[key]) }
          end
          owners={'TrainerName'=>['Trainer',0], 'TrainerPokemon'=>['Trainer',0], 'NPCText'=>['NPC',0], 'NPCHeals'=>['NPC',0], 'TreasureItem'=>['TreasureTier',0], 'BountyDescription'=>['Bounty',0], 'BountyPokemon'=>['Bounty',0], 'MilestoneText'=>['Milestone',0]}
          owners.each do |key,(parent,column)|
            ids=rows(d,parent).map { |r| r[column] }
            rows(d,key).each { |r| raise Error,"orphan #{key} #{r[0]}" unless ids.include?(r[0]) }
          end
          %w[Trainer NPC NPCHeals Criminal TreasureTier Bounty Milestone ItemGraphic].each do |key|
            ids=rows(d,key).map(&:first); raise Error,"duplicate #{key} ID" if ids.uniq.size!=ids.size
          end
          %w[Wild Item TrainerPokemon BountyPokemon TrainerSpecies].each do |key|
            rows(d,key).each do |r|
              species_column={'Wild'=>2,'TrainerPokemon'=>1,'BountyPokemon'=>1,'TrainerSpecies'=>0}[key]
              if species_column; ref.call(:Species,r[species_column]); else; ref.call(:Item,r[0]); end
            end
          end
          {'SmugglerItem'=>4,'CriminalBribe'=>3}.each do |key,column|
            rows(d,key).group_by(&:first).each { |item,rules| check_ranges(rules.map { |r| r[column] },"#{key} #{item}") }
          end
          rows(d,'Item').group_by(&:first).each { |item,rules| check_ranges(rules.map { |r| r[1] },"Item #{item}") }
          rows(d,'Item').each { |r| raise Error,'unknown item rarity' unless rows(d,'ItemGraphic').any? { |g| g[0]==r[3] } }
          rows(d,'Wild').each { |r| ref.call(:EncounterType,r[1]); raise Error,'wild level range invalid' if r[4]>r[5] || r[5]>100 }
          rows(d,'WildRate').each { |r| ref.call(:EncounterType,r[0]) }
          {'SmugglerItem'=>0,'CriminalBribe'=>0,'TreasureItem'=>1,'ForcedItem'=>1}.each { |key,col| rows(d,key).each { |r| ref.call(:Item,r[col]) } }
          %w[ItemAllowed NPCItemPool].each { |key| (d[key] || []).each { |i| ref.call(:Item,i) } }
          %w[Trainer NPC Criminal].each do |key|
            rows(d,key).each do |r|
              ref.call(:TrainerType,r[key=='Criminal' ? 3 : 1]) unless key=='NPC'
              if key=='NPC'; ref.call(:Item,r[7]); ref.call(:Item,r[8]); end
            end
          end
          rows(d,'Trainer').each do |r|
            names=rows(d,'TrainerName').select { |n| n[0]==r[0] }
            raise Error,"trainer #{r[0]} needs names" if names.empty? || names.any? { |n| n[1].empty? }
            if d['TrainerPartyMode']==:fixed
              team=rows(d,'TrainerPokemon').select { |t| t[0]==r[0] }
              raise Error,"trainer #{r[0]} requires 1..6 fixed Pokemon" unless team.size.between?(1,6)
            elsif d['TrainerPartyMode']==:pbs
              names.each { |n| ref.call(:Trainer,[r[1],n[1],r[5]]) }
            end
          end
          raise Error,'random trainers require TrainerSpecies' if d['TrainerChance'].to_f>0 && d['TrainerPartyMode']==:random && rows(d,'TrainerSpecies').empty?
          rows(d,'TrainerPokemon').each { |r| raise Error,'trainer level exceeds maximum' if r[2]>100 }
          rows(d,'BountyPokemon').each { |r| raise Error,'bounty level exceeds maximum' if r[2]>100 }
          rows(d,'CriminalText').each { |r| raise Error,"unknown CriminalText #{r[0]}" unless %w[caught offer accept_choice refuse_choice accepted repeat refused arrested].include?(r[0]) }
          rows(d,'NPCText').each do |r|
            npc=rows(d,'NPC').find { |n| n[0]==r[0] }
            valid={outlaw:%w[caught turned_in after_bribe repeat],nurse:%w[before after exhausted],quest:%w[no_item have_item reward]}[npc[1]]
            raise Error,"unknown NPCText #{r[0]}/#{r[1]}" unless valid.include?(r[1])
          end
          rows(d,'NPCHeals').each do |id,_count|
            npc=rows(d,'NPC').find { |n| n[0]==id }
            raise Error,"NPCHeals #{id} requires a nurse" unless npc[1]==:nurse
          end
          rows(d,'Bounty').each { |r| ref.call(:Item,r[6]); ref.call(:TrainerType,r[8]); raise Error,'bounty reward quantity must be positive' if r[6]!=:none && r[7]<1; raise Error,'bounty party exceeds six' if r[10]>6 }
          allowed=d['Traps'] || []
          allowed.each { |trap| raise Error,"unknown trap #{trap}" unless data['pmd_traps'][trap] }
          rows(d,'TrapWeight').each { |r| raise Error,'TrapWeight not in Traps' unless allowed.include?(r[0]) }
          rows(d,'ForcedTrap').each { |r| raise Error,'ForcedTrap not in Traps' unless allowed.include?(r[1]) }
          {'TrainerChance'=>'Trainer','SmugglerChance'=>'SmugglerItem','CriminalChance'=>'Criminal','TreasureChance'=>'TreasureTier'}.each { |chance,key| raise Error,"enabled #{chance} has empty #{key}" if d[chance].to_f>0 && rows(d,key).empty? }
          %w[Foe Hunter].each do |prefix|
            next unless d[prefix+'Enabled']
            raise Error,"#{prefix}Species is empty" if (d[prefix+'Species'] || []).empty?
            d[prefix+'Species'].each { |s| ref.call(:Species,s) }
          end
          rows(d,'Milestone').each do |r|
            ref.call(:Species,r[7])
            raise Error,'milestone transfer needs destination' if [:teleport_away,:rest_area].include?(r[2]) && r[3]==0
            raise Error,'boss milestone needs species and level' if r[2]==:boss && (r[7]==:none || r[8]<1)
          end
        rescue Error => ex
          raise Error,"pmd_dungeons.txt [#{id}]: #{ex.message}"
        end
      end
      roles=%i[floor void floor_patch floor_decoration floor_decoration_large void_decoration void_decoration_large water_patch path_patch walls wall_top]
      [1,2,3,4,6,7,8,9].each { |n| roles << "wall_#{n}".to_sym; roles << "upper_wall_#{n}".to_sym }
      [1,3,7,9].each { |n| roles << "wall_in_#{n}".to_sym; roles << "upper_wall_in_#{n}".to_sym }
      data['pmd_tilesets'].each do |id,palette|
        raise Error,"palette #{id}: Tileset required" unless palette['Tileset']
        (rows(palette,'Tile')+rows(palette,'Autotile')).each { |r| raise Error,"palette #{id}: unknown tile role #{r[1]}" unless roles.include?(r[1]) }
      end
      data['pmd_traps'].each do |id,t|
        kind=t['Type']; raise Error,"trap #{id}: Type required" unless kind
        required={status:%w[Status],floor_shift:%w[Direction],miniboss:%w[Species Level]}[kind] || []
        required.each { |k| raise Error,"trap #{id}: #{k} required" unless t[k] }
        specific={Status:[:status],DamageFraction:[:explosion,:spikes],DampBlocked:[:explosion],PPFraction:[:pp_down],IgnoreRaised:[:spikes],TeleportDistance:[:teleport_room],Direction:[:floor_shift],Species:[:miniboss],Level:[:miniboss]}
        specific.each { |k,types| raise Error,"trap #{id}: inapplicable #{k}" if t.key?(k.to_s) && !types.include?(kind) }
        ref.call(:Species,t['Species']); ref.call(:Status,t['Status'])
      end
      data['pmd_companions'].each do |id,a|
        if id.to_s.include?('@')
          ally,dungeon=id.to_s.split('@').map(&:to_sym)
          raise Error,"unknown companion scope #{id}" unless data['pmd_companions'][ally] && data['pmd_dungeons'][dungeon]
          next
        end
        %w[TrainerType TrainerName Graphic].each { |k| raise Error,"companion #{id}: #{k} required" if !a[k] || a[k].to_s.empty? }
        ref.call(:TrainerType,a['TrainerType'])
        ref.call(:Trainer,[a['TrainerType'],a['TrainerName'],a.fetch('TrainerVersion',0)]) if a['PartyMode']==:pbs
        if (a['PartyMode'] || :generated)==:generated
          raise Error,"companion #{id}: expected 1..6 Pokemon" unless rows(a,'Pokemon').size.between?(1,6)
          rows(a,'Pokemon').each { |r| ref.call(:Species,r[0]); raise Error,'companion level exceeds maximum' if r[1]>100 }
        end
        %w[AskMessage ConfirmMessage AcceptChoice DeclineChoice KeepChoice TeamChoice DismissChoice DismissAcceptChoice DismissDeclineChoice].each { |k| raise Error,"companion #{id}: empty #{k}" if a.key?(k) && a[k].to_s.empty? }
      end
      global=data['pmd_global'][:GLOBAL]
      rows(global,'StatusImmunity').each { |r| ref.call(:Status,r[0]); r[1..-1].each { |type| ref.call(:Type,type) } }
      %w[StatusImmunity FloorCardBackground].each do |key|
        ids=rows(global,key).map(&:first)
        raise Error,"duplicate global #{key}" if ids.uniq.size!=ids.size
      end
      vars=%w[BankVariable LawVariable ChaosVariable].map { |k| data['pmd_global'][:GLOBAL][k] }.compact
      raise Error,'Bank/Law/Chaos variables must be distinct' unless vars.uniq==vars
      data
    end

    def check_ranges(ranges,label)
      sorted=ranges.sort_by(&:first)
      sorted.each_cons(2) { |a,b| raise Error,"overlapping #{label}" if !a[1] || a[1]>=b[0] }
    end

    def current
      return nil unless bundle
      run=defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:pmdSeededRun) ? $PokemonGlobal.pmdSeededRun : nil
      id=run && run[:active] && run[:dungeon_id]
      return bundle['pmd_dungeons'][id] if id && bundle['pmd_dungeons'][id]
      map=context_map || (defined?($game_map) && $game_map && $game_map.map_id)
      map=run[:map] if run && run[:active] && run[:map]
      bundle['pmd_dungeons'].values.find { |d| (d['MapIDs'] || []).include?(map) }
    end

    def dungeon_id(map)
      return nil unless bundle
      pair=bundle['pmd_dungeons'].find { |_id,d| (d['MapIDs'] || []).include?(map) }
      pair && pair[0]
    end

    def floor_number
      return [PMDDungeon.current_floor.to_i,1].max if PMDDungeon.respond_to?(:current_floor)
      1
    end

    def eligible(data,key,column)
      rows(data,key).select { |r| covers?(r[column],floor_number) }
    end

    def as_range(value)
      return nil unless value
      return (value[0]..(value[1] || 2_147_483_647))
    end

    def snake(key)
      key.gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').gsub(/([a-z0-9])([A-Z])/,'\1_\2').downcase.to_sym
    end

    SIMPLE = {
      Config: {EVENT_TEMPLATE_MAP_ID:'EventTemplateMap',FLOOR_CARD_DISPLAY_FRAMES:'FloorCardFrames',MINIMAP_ICON_BIG:'MinimapIcon',MINIMAP_ICON_SIZE_SMALL:'MinimapSmallSize',MINIMAP_ICON_SIZE_FULL:'MinimapFullSize',FLOOR_CARD_DEFAULT_TITLE:'DefaultTitle'},
      EventConfig: {MAX_EVENTS_PER_FLOOR:'MaxEvents',NPC_ITEM_POOL:'NPCItemPool'},
      FeatureConfig: {TRAINER_CHANCE:'TrainerChance',TRAINER_MIN_FLOOR:'TrainerMinFloor',TRAINER_SIGHT:'TrainerSight',TRAINER_MONEY_BASE:'TrainerMoneyBase',HUNTER_ENABLED:'HunterEnabled',HUNTER_MIN_FLOOR:'HunterMinFloor',HUNTER_SECONDS:'HunterSpawnSeconds',HUNTER_GRAPHIC:'HunterGraphic',HUNTER_NAME:'HunterName',HUNTER_MOVE_SPEED:'HunterSpeed',FOE_ENABLED:'FoeEnabled',FOE_START_DEPTH:'FoeStartDepth',FOE_CLIMB_STEPS:'FoeClimbSteps',FOE_GRAPHIC:'FoeGraphic',FOE_MOVE_SPEED:'FoeSpeed',SMUGGLER_CHANCE:'SmugglerChance',SMUGGLER_MIN_FLOOR:'SmugglerMinFloor',SMUGGLER_GRAPHIC:'SmugglerGraphic',SMUGGLER_PRICE_MULT:'SmugglerPriceMultiplier',SMUGGLER_STOCK_SIZE:'SmugglerStockSize',SMUGGLER_SHOP_ART:'SmugglerShopArt',ITEM_RESTRICTION:'ItemRestriction',ITEM_RESTRICTION_ALLOWED:'ItemAllowed',DEFEAT_MONEY_FRACTION:'DefeatMoneyFraction',DEFEAT_DESTINATION:'DefeatDestination',BANK_VARIABLE:'BankVariable',BOUNTY_SEAL_EXTRA_ENTRANCES:'BountySealEntrances',BOUNTY_SEAL_GRAPHIC:'BountySealGraphic',CRIMINAL_CHANCE:'CriminalChance',CRIMINAL_MIN_FLOOR:'CriminalMinFloor',LAW_VARIABLE:'LawVariable',CHAOS_VARIABLE:'ChaosVariable',AURA_STEP:'CriminalAuraStep',ALLY_FOLLOWER_NAME:'AllyFollowerName',GRASS_PATCH_FACTOR:'GrassPatchFactor',DEBUG_MENU:'DebugMenu',HIDDEN_OPACITY:'HiddenOpacity',TREASURE_ROOM_CHANCE:'TreasureChance'}
    }

    def setting(mod,key)
      legacy=proc { PMDDungeon.const_get(mod).const_get(key) }
      return legacy.call unless bundle
      global=bundle['pmd_global'][:GLOBAL]
      d=current || bundle['defaults'] || {}
      source=d.merge(global)
      prop=(SIMPLE[mod] || {})[key]
      if prop && GENERATION.key?(prop)
        override=rows(d,'FloorSetting').find { |r| r[1]==prop && covers?(r[0],floor_number) }
        if override
          value=tuple(override[2..-1],GENERATION[prop])
          return value.length==1 ? value[0] : value
        end
      end
      return source[prop] if prop && source.key?(prop)
      case [mod,key]
      when [:Config,:MAIN_DUNGEON_MAP_IDS]; return bundle['pmd_dungeons'].values.flat_map { |r| r['MapIDs'] }
      when [:Config,:DUNGEON_MAP_BY_FLOOR]; return rows(d,'FloorMap').to_h { |r| [as_range(r[0]),r[1]] } unless rows(d,'FloorMap').empty?
      when [:Config,:DUNGEON_NAMES]; return bundle['pmd_dungeons'].flat_map { |_id,r| r['MapIDs'].map { |m| [m,r['Name'] || 'Dungeon'] } }.to_h
      when [:Config,:DUNGEON_FLOOR_VARIABLE_ID]; return global['FloorVariable'].to_i>0 ? global['FloorVariable'] : nil
      when [:Config,:TEMPLATE_EVENT_IDS]; return {event:global['EventTemplate'] || 1,item:global['ItemTemplate'] || 2,trap:global['TrapTemplate'] || 4}
      when [:Config,:FLOOR_CARD_BG_BY_TIME]; return rows(global,'FloorCardBackground').to_h unless !global.key?('FloorCardBackground')
      when [:Config,:DUNGEON_TILESET_DATA_ID_BY_MAP]
        return bundle['pmd_dungeons'].flat_map { |_id,r| r['MapIDs'].map { |m| [m,r['Tileset']] } }.to_h
      when [:EventConfig,:MAX_EVENTS_BY_DUNGEON_AND_FLOOR]; return (d['MapIDs'] || []).to_h { |m| [m,rows(d,'MaxEventsOnFloor').to_h { |r| [as_range(r[0]),r[1]] }] }
      when [:EventConfig,:ITEM_SPAWN_CHANCE],[:EventConfig,:NPC_SPAWN_CHANCE],[:EventConfig,:TRAP_SPAWN_CHANCE]
        return d['EventWeights'][{ITEM_SPAWN_CHANCE:0,NPC_SPAWN_CHANCE:1,TRAP_SPAWN_CHANCE:2}[key]] if d['EventWeights']
      when [:EventConfig,:EVENT_POOL]; return []
      when [:EventConfig,:NPC_POOL]
        return rows(d,'NPC').map do |r|
          n={npc:r[0],type:r[1],floors:as_range(r[2]),spawn_chance:r[3],graphic:r[4],unique_run:r[5],max_per_floor:r[6]>0 ? r[6] : nil,required_item:r[7]==:none ? nil : r[7],reward_item:r[8]==:none ? nil : r[8],weight:r[9]}
          rows(d,'NPCText').each { |id,k,v| n['dialogue_'+k]=v if id==r[0] }
          heals=rows(d,'NPCHeals').find { |id,_count| id==r[0] }
          n[:heal_limit]=heals ? heals[1] : 1 if r[1]==:nurse
          n.transform_keys { |k| k.to_sym }
        end if d.key?('NPC')
      when [:ItemConfig,:ITEM_POOL]
        return rows(d,'Item').map { |r| {item:r[0],floors:as_range(r[1]),weight:r[2],rarity:r[3],unique_run:r[4],max_total:r[5]>0 ? r[5] : nil,max_per_floor:r[6]>0 ? r[6] : nil,min_floor_gap:r[7]>0 ? r[7] : nil} } if d.key?('Item')
      when [:ItemConfig,:ITEM_RARITY_GRAPHIC]; return rows(d,'ItemGraphic').to_h { |r| [r[0],{graphic:r[1],open_direction:r[2],open_pattern:r[3]}] } if d.key?('ItemGraphic')
      when [:TrapConfig,:STATUS_TYPE_IMMUNITIES]; return rows(global,'StatusImmunity').to_h { |r| [r[0],r[1..-1]] } if global.key?('StatusImmunity')
      when [:TrapConfig,:TRAP_POOL]
        ids=(d['Traps'] || bundle['pmd_traps'].keys).select do |id|
          filters=rows(d,'TrapWeight').select { |r| r[0]==id }
          filters.empty? || filters.any? { |r| covers?(r[1],floor_number) }
        end
        return ids.map do |id|
          rule=bundle['pmd_traps'].fetch(id); h={id:id,type:rule['Type'],floors:as_range(rule['Floors'] || [1,nil]),weight:rule['Weight'] || 1}
          rule.each { |k,v| h[snake(k)]=v unless %w[Type Floors Weight].include?(k) }
          override=eligible(d,'TrapWeight',1).find { |r| r[0]==id }; h[:weight]=override[2] if override
          h
        end
      when [:FeatureConfig,:TRAINERS]
        return eligible(d,'Trainer',4).map { |r| {id:r[0],type:r[1],graphic:r[2],weight:r[3],version:r[5],names:rows(d,'TrainerName').select { |n| n[0]==r[0] }.map { |n| n[1] }} } if d.key?('Trainer')
      when [:FeatureConfig,:TRAINER_SPECIES]; return rows(d,'TrainerSpecies').map(&:first) if d.key?('TrainerSpecies')
      when [:FeatureConfig,:SMUGGLER_STOCK]; return eligible(d,'SmugglerItem',4).map { |r| [r[0],r[1]] } if d.key?('SmugglerItem')
      when [:FeatureConfig,:CRIMINALS]; return eligible(d,'Criminal',5).map { |r| {name:r[1],graphic:r[2],portrait:r[3],weight:r[4]} } if d.key?('Criminal')
      when [:FeatureConfig,:CRIMINAL_BRIBES]; return eligible(d,'CriminalBribe',3).map(&:first) if d.key?('CriminalBribe')
      when [:FeatureConfig,:FOE_RAID],[:FeatureConfig,:HUNTER_RAID]
        prefix=key==:FOE_RAID ? 'Foe' : 'Hunter'
        return {species:d[prefix+'Species'],style:d[prefix+'RaidStyle'],rank:d[prefix+'RaidRank'],level_bonus:d[prefix+'LevelBonus'],turn_count:d[prefix+'TurnCount'],ko_count:d[prefix+'KOCount'],shield_hp:d[prefix+'ShieldHP'],extra_actions:d[prefix+'ExtraActions'] || []} if d.key?(prefix+'Species')
      when [:FeatureConfig,:TREASURE_CHESTS]
        return eligible(d,'TreasureTier',3).map { |r| {id:r[0],graphic:r[1],weight:r[2],loot:eligible(d,'TreasureItem',4).select { |i| i[0]==r[0] }.map { |i| i[1] }} } if d.key?('TreasureTier')
      when [:FeatureConfig,:BOUNTIES]
        return rows(d,'Bounty').map { |r| {id:r[0],kind:r[1],name:r[2],floors:as_range(r[3]),graphic:r[4],reward_money:r[5],reward_item:r[6]==:none ? nil : r[6],reward_quantity:r[7],trainer_type:r[8]==:none ? nil : r[8],trainer_name:r[9],party_count:r[10],level_bonus:r[11],description:(rows(d,'BountyDescription').find { |x| x[0]==r[0] } || [nil,''])[1]} } if d.key?('Bounty')
      when [:FeatureConfig,:ALLIES]
        return bundle['pmd_companions'].reject { |id,_r| id.to_s.include?('@') }.to_h { |id,r| [id,{name:r['TrainerName'],trainer_type:r['TrainerType'],charset:r['Graphic'],party:rows(r,'Pokemon').map(&:first),min_level:r['MinLevel'] || 5,level_offset:r['LevelOffset'] || 0}] }
      when [:FeatureConfig,:HIDING_TILE_RANGES]; return bundle['pmd_tilesets'].values.to_h { |r| [r['Tileset'],(r['HidingTiles'] || []).map { |v| as_range(v) }] }
      when [:FeatureConfig,:HIDING_TERRAIN_TAGS]; return palette ? palette.fetch('HidingTerrainTags',[2]) : [2]
      when [:MilestoneConfig,:MILESTONES]
        return rows(d,'Milestone').map do |r|
          m={id:r[0],floor:r[1],type:r[2],destination_map:r[3]>0 ? r[3] : nil,x:r[4],y:r[5],direction:r[6],species:r[7],level:r[8]}
          rows(d,'MilestoneText').each { |id,k,v| m[k==:before ? :message_before : k==:win ? :message_win : :message]=v if id==r[0] }; m
        end if d.key?('Milestone')
      end
      legacy.call
    end

    def palette
      d=current
      d && d['Tileset'] && bundle['pmd_tilesets'][d['Tileset']]
    end
  end
end

module GameData
  class PMDRecord
    attr_reader :id, :properties
    def initialize(hash); @id=hash[:id]; @properties=hash[:properties]; end
    def self.register(hash); self::DATA[hash[:id]]=new(hash); end
    def self.get(id); self::DATA.fetch(id.to_sym); end
    def self.try_get(id); id && self::DATA[id.to_sym]; end
    def self.exists?(id); !!try_get(id); end
    def self.keys; self::DATA.keys; end
    def self.each(&block); self::DATA.each_value(&block); end
    def self.load; end
    def self.save; ::PMDDungeon::DataStore.publish('.',::PMDDungeon::DataStore.bundle); end
  end
  %w[PMDGlobal PMDDungeon PMDTileset PMDTrap PMDCompanion].each_with_index do |name,index|
    klass=Class.new(PMDRecord)
    klass.const_set(:DATA,{})
    klass.const_set(:OPTIONAL,true)
    klass.const_set(:DATA_FILENAME,::PMDDungeon::DataStore::FILES[index]+'.dat')
    klass.const_set(:PBS_BASE_FILENAME,::PMDDungeon::DataStore::FILES[index])
    klass.const_set(:SCHEMA,::PMDDungeon::DataStore::SCHEMAS[index])
    const_set(name,klass)
  end
end
