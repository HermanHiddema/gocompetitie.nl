class MakeMatchVenueRequired < ActiveRecord::Migration[8.1]
  # A placeholder venue for matches of which the location is not known yet. It
  # uses a fallback club and sorts to the top of the list of venues by name.
  TO_BE_DETERMINED_CLUB = {
    abbrev: "xxxx",
    name: "Geen"
  }.freeze

  TO_BE_DETERMINED = {
    name: "(Nader te bepalen)",
    address: "Onbekend",
    city: "in onderling overleg",
    playing_day: 0,
    playing_time: "-"
  }.freeze

  class MigrationClub < ActiveRecord::Base
    self.table_name = "clubs"
  end

  class MigrationVenue < ActiveRecord::Base
    self.table_name = "venues"
  end

  class MigrationMatch < ActiveRecord::Base
    self.table_name = "matches"
  end

  def up
    club = MigrationClub.find_or_create_by!(abbrev: TO_BE_DETERMINED_CLUB[:abbrev]) do |record|
      record.name = TO_BE_DETERMINED_CLUB[:name]
    end

    venue = MigrationVenue.find_or_initialize_by(name: TO_BE_DETERMINED[:name])
    venue.assign_attributes(TO_BE_DETERMINED.merge(club_id: club.id))
    venue.save!
    MigrationMatch.where(venue_id: nil).update_all(venue_id: venue.id)

    change_column_null :matches, :venue_id, false
  end

  def down
    change_column_null :matches, :venue_id, true

    club = MigrationClub.find_by(abbrev: TO_BE_DETERMINED_CLUB[:abbrev])
    venue = MigrationVenue.find_by(name: TO_BE_DETERMINED[:name], club_id: club&.id)
    MigrationMatch.where(venue_id: venue.id).update_all(venue_id: nil) if venue
    venue&.destroy!
  end
end
