module PMDDungeon
  module MilestoneConfig
    # Milestone entries are checked when a new floor is entered.
    # Use one entry per floor; first match wins.
    #
    # Example:
    # MILESTONES = [
    #   {
    #     floor: 5,
    #     type: :teleport_away,
    #     destination_map: 102,
    #     message:
    #   },
    #   {
    #     floor: 8,
    #     type: :boss,
    #     species: :GENGAR,
    #     level: 40,
    #     message_before:,
    #     message_win:,
    #     destination_map:
    #   }
    # ]
    MILESTONES = []
  end
end
