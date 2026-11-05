# Native engine adapters. The PBS contract/compiler itself is engine-independent.
module PMDDungeon
  module DataRuntime
    module_function

    def config
      DataStore.current
    end

    def weighted(rows,weight_column,rng=nil)
      return nil if rows.empty?
      total=rows.sum { |r| r[weight_column].to_f }
      roll=(rng ? rng.rand : rand)*total
      rows.each { |r| roll-=r[weight_column].to_f; return r if roll<0 }
      rows.last
    end

    PARAMS={
      'DungeonSize'=>[:cell_count_x,:cell_count_y], 'CellSize'=>[:cell_width,:cell_height],
      'MinRoomSize'=>[:room_min_width,:room_min_height], 'MaxRoomSize'=>[:room_max_width,:room_max_height],
      'CorridorWidth'=>[:corridor_width], 'ShiftCorridors'=>[:random_corridor_shift],
      'NodeLayout'=>[:node_layout], 'RoomLayout'=>[:room_layout], 'RoomChance'=>[:room_chance],
      'ExtraConnections'=>[:extra_connections_count], 'FloorPatches'=>[:floor_patch_radius,:floor_patch_chance,:floor_patch_smooth_rate],
      'FloorDecorations'=>[:floor_decoration_density,:floor_decoration_large_density],
      'VoidDecorations'=>[:void_decoration_density,:void_decoration_large_density]
    }
    def apply_parameters(params)
      return unless config
      values=config.dup
      DataStore.rows(config,'FloorSetting').each do |r|
        next unless DataStore.covers?(r[0],DataStore.floor_number)
        tuple=DataStore.tuple(r[2..-1],DataStore::GENERATION[r[1]])
        values[r[1]]=tuple.length==1 ? tuple[0] : tuple
      end
      # Legacy generation rolls room shape before generating the maze.
      if values['RoomLayout']==:legacy_random
        values['RoomLayout']=[:ring,:antiring,:plus,:cross,:quadrants,:full].sample
      end
      PARAMS.each do |key,vars|
        next unless values.key?(key)
        parts=vars.length>1 ? values[key] : [values[key]]
        vars.each_with_index { |var,i| params.instance_variable_set('@'+var.to_s,parts[i]) }
      end
    end

    def tileset_data
      palette=DataStore.palette
      return nil unless palette
      hash={id:palette['Tileset'],tile:[],autotile:[]}
      palette.each do |key,value|
        case key
        when 'Tile'; hash[:tile]=value
        when 'Autotile'; hash[:autotile]=value
        when 'SnapToLargeGrid','LargeVoidTiles','LargeWallTiles','LargeFloorTiles','DoubleWalls','FloorPatchUnderWalls','ThinNorthWallOffset','Flags'
          hash[DataStore.snake(key)]=value
        end
      end
      GameData::DungeonTileset.new(hash)
    end

    def floor_level(bonus=0,fallback=1)
      base,step,low,high=config && config['WildLevel'] || [4,2,1,100]
      [[base+DataStore.floor_number*step+bonus,fallback,low].max,high,GameData::GrowthRate.max_level].min
    end

    def trainer_party(id,fl,count,bonus=0)
      rows=DataStore.rows(config,'TrainerPokemon').select { |r| r[0]==id }
      if config['TrainerPartyMode']==:fixed
        return rows.map { |r| [r[1],r[2]>0 ? r[2] : floor_level(bonus)] }
      end
      pool=DataStore.rows(config,'TrainerSpecies')
      Array.new(count) { [weighted(pool,1)[0],floor_level(bonus)] }
    end

    def companion_sync
      Allies.sync_partner
    end

    def validate_raids(data)
      data['pmd_dungeons'].each do |id,d|
        %w[Foe Hunter].each do |prefix|
          next unless d[prefix+'Enabled']
          style=d[prefix+'RaidStyle']
          raise DataStore::Error,"#{id}: DBK Raid Battles/style #{style} unavailable" unless defined?(::RaidBattle) && defined?(GameData::RaidType) && GameData::RaidType.exists?(style)
          raise DataStore::Error,'raid rank must be 1..7' unless d[prefix+'RaidRank'].between?(1,7)
          d[prefix+'Species'].each do |species|
            raise DataStore::Error,"#{species} is not a #{style} raid species" unless GameData::Species.get(species).raid_species?(style)
          end
        end
      end
    end

    def validate_native!
      return unless DataStore.bundle
      DataStore.validate(DataStore.bundle,DataStore.method(:native_reference!))
      validate_raids(DataStore.bundle)
    end
  end
end

if defined?(Compiler) && Compiler.respond_to?(:compile_pbs_files)
  module Compiler
    class << self
      alias pmd_data_compile_pbs_files compile_pbs_files
      def compile_pbs_files(*args)
        result=pmd_data_compile_pbs_files(*args)
        if PMDDungeon::DataStore::FILES.any? { |f| File.file?(File.join('PBS',f+'.txt')) }
          data=PMDDungeon::DataStore.compile_directory('.',PMDDungeon::DataStore.method(:native_reference!))
          PMDDungeon::DataRuntime.validate_raids(data)
          PMDDungeon::DataStore.publish('.',data)
        end
        result
      end
    end
  end
end
if GameData.respond_to?(:load_all)
  module GameData
    class << self
      alias pmd_data_load_all load_all
      def load_all
        pmd_data_load_all
        ::PMDDungeon::DataStore.boot('.',defined?($DEBUG) && $DEBUG)
      end
    end
  end
end

module PMDDungeon
  class << self
    alias pmd_data_wild_level dungeon_wild_level_for_floor if method_defined?(:dungeon_wild_level_for_floor)
    def dungeon_wild_level_for_floor(fl,fallback)
      return pmd_data_wild_level(fl,fallback) if !DataStore.bundle && respond_to?(:pmd_data_wild_level)
      return DataRuntime.floor_level(0,fallback)
    end
  end
end

# Temporarily replace native tables, preserving ability/repel/time-of-day rules.
module PMDEncounterTables
    def with_pmd_tables
      data=PMDDungeon::DataStore.current
      return yield unless data && PMDDungeon::Features.in_dungeon?
      old_tables=@encounter_tables; old_chances=@step_chances
      mode=data.fetch('WildMode',:map)
      if mode==:none
        @encounter_tables={}; @step_chances={}
      elsif mode==:table
        @encounter_tables={}; @step_chances={}
        PMDDungeon::DataStore.eligible(data,'Wild',0).each do |r|
          (@encounter_tables[r[1]]||=[]) << [r[3],r[2],r[4],r[5]]
          @step_chances[r[1]]=GameData::EncounterType.get(r[1]).trigger_chance
        end
        @encounter_tables.each_value do |table|
          denominator=table.map { |r| r[0].to_r.denominator }.inject(1) { |a,b| a.lcm(b) }
          table.each { |r| r[0]=(r[0].to_r*denominator).to_i }
        end
        PMDDungeon::DataStore.rows(data,'WildRate').each { |method,rate| @step_chances[method]=rate }
      elsif data['EncounterMap'] && defined?(GameData::Encounter)
        native=GameData::Encounter.get(data['EncounterMap'],$PokemonGlobal.encounter_version)
        @encounter_tables=native ? native.types : {}
        @step_chances=native ? native.step_chances : {}
      end
      yield
    ensure
      if defined?(old_tables) && old_tables
        @encounter_tables=old_tables; @step_chances=old_chances
      end
    end

    def has_encounter_type?(type)
      with_pmd_tables { super }
    end
    def encounter_type
      with_pmd_tables { super }
    end
    def encounter_triggered?(*args)
      with_pmd_tables { super }
    end
    def choose_wild_pokemon(*args)
      result=with_pmd_tables { super }
      data=PMDDungeon::DataStore.current
      if result && data && data['WildMode']==:table && data['WildLevelMode']==:floor && PMDDungeon::Features.in_dungeon?
        result[1]=PMDDungeon::DataRuntime.floor_level(0,result[1])
      end
      result
    end
  end
PokemonEncounters.prepend(PMDEncounterTables) if defined?(PokemonEncounters)

if defined?(GameData::MapMetadata)
  module PMDMapMusic
    {wild_battle_BGM:'WildBattleBGM',trainer_battle_BGM:'TrainerBattleBGM',wild_victory_BGM:'WildVictoryBGM',trainer_victory_BGM:'TrainerVictoryBGM'}.each do |method,key|
      define_method(method) do
        data=::PMDDungeon::DataStore.current
        value=data && data[key]
        if data && ::PMDDungeon::Features.in_dungeon? && data['MapIDs'].include?(id) && value && !value.empty?
          value
        else
          super()
        end
      end
    end
  end
  GameData::MapMetadata.prepend(PMDMapMusic)
end
EventHandlers.add(:on_enter_map,:pmd_data_music,proc { |_old|
  data=PMDDungeon::DataStore.current
  if data && PMDDungeon::Features.in_dungeon? && data['BGM'] && !data['BGM'].empty?
    pbBGMPlay(data['BGM'],data.fetch('BGMVolume',100),data.fetch('BGMPitch',100))
  end
})

EventHandlers.add(:on_enter_map,:pmd_companion_scope,proc { |_old| PMDDungeon::Allies.sync_partner })
EventHandlers.add(:on_map_or_spriteset_change,:pmd_companion_scope,proc { |*_args| PMDDungeon::Allies.sync_partner })
EventHandlers.add(:on_player_step_taken,:pmd_companion_flavour,proc { PMDDungeon::Allies.flavour_step })
