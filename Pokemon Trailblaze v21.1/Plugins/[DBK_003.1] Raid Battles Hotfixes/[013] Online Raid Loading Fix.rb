#===============================================================================
# Online Raid IV/EV Loading Fix
#===============================================================================
# Bug: NoMethodError: undefined method `length' for nil:NilClass
# Location: [002] Raid Den - Events.rb:252 in pbLoadLiveRaidData
# Root Cause: compact! returns nil when array has no nil elements
# Impact: Online raids crash when loading IV/EV data
# Solution: Use compact instead of compact! to avoid nil return
#===============================================================================

module LiveRaidDataFix
  def self.pbLoadLiveRaidData
    lineno = 1
    species = [nil, 0]
    pkmn_data = {}
    raid_data = {
      :style    => :Basic,
      :online   => true,
      :raid_den => true
    }
    if nil_or_empty?(Settings::LIVE_RAID_EVENT_URL)
      return species, pkmn_data, raid_data
    end
    schema = LiveRaidEvent::SCHEMA
    data = pbDownloadToString(Settings::LIVE_RAID_EVENT_URL)
    data.each_line do |line|
      if lineno == 1 && line[0].ord == 0xEF && line[1].ord == 0xBB && line[2].ord == 0xBF
        line = line[3, line.length - 3]
      end
      line.force_encoding(Encoding::UTF_8)
      line = Compiler.prepline(line)
      FileLineData.setLine(line, lineno) if !line[/^\\#/] && !line[/^\\s*$/]
      next if !line[/^\\s*(\\w+)\\s*=\\s*(.*)$/]
      key = $~[1]
      property_value = Compiler.get_csv_record($~[2], schema[key])
      
      # FIX: Use compact instead of compact! to avoid nil return
      if ["IV", "EV"].include?(key)
        property_value = property_value.compact  # Returns array, never nil
        property_value = property_value.first if property_value.length < 6
      end
      
      case key
      when "Species" then species[0] = property_value
      when "Form"    then species[1] = property_value
      else
        if key.include?("Raid")
          raid_data[schema[key][0]] = property_value
        else
          pkmn_data[schema[key][0]] = property_value
        end
      end
      lineno += 1
    end
    return species, pkmn_data, raid_data
  end
end

# Override the original method
def pbLoadLiveRaidData
  LiveRaidDataFix.pbLoadLiveRaidData
end

puts "[Raid Hotfix] Online Raid IV/EV Loading Fix loaded"
