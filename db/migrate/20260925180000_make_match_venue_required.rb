class MakeMatchVenueRequired < ActiveRecord::Migration[8.1]
  # A placeholder venue for matches of which the location is not known yet. It
  # has no club and sorts to the top of the list of venues by name.
  TO_BE_DETERMINED = {
    name: "(Nader te bepalen)",
    address: "Onbekend",
    city: "in onderling overleg",
    playing_day: 0,
    playing_time: "-"
  }.freeze

  class MigrationVenue < ActiveRecord::Base
    self.table_name = "venues"
  end

  class MigrationMatch < ActiveRecord::Base
    self.table_name = "matches"
  end

  def up
    change_column_null :venues, :club_id, true

    venue = MigrationVenue.find_or_create_by!(name: TO_BE_DETERMINED[:name]) do |record|
      record.assign_attributes(TO_BE_DETERMINED.except(:name))
    end
    MigrationMatch.where(venue_id: nil).update_all(venue_id: venue.id)

    change_column_null :matches, :venue_id, false
  end

  def down
    change_column_null :matches, :venue_id, true

    # Venues without a club cannot be kept once a club is required again.
    clubless = MigrationVenue.where(club_id: nil)
    MigrationMatch.where(venue_id: clubless.select(:id)).update_all(venue_id: nil)
    clubless.delete_all

    change_column_null :venues, :club_id, false
  end
end
