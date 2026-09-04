require "test_helper"

class VenueTest < ActiveSupport::TestCase
  test "the playing day is translated to a Dutch day name" do
    assert_equal "dinsdag", venues(:amsterdam).playing_day_name
  end

  test "a venue requires club, name, address, city and playing details" do
    venue = Venue.new

    assert_not venue.valid?
    assert_equal %i[club name address city playing_time playing_day].sort, venue.errors.attribute_names.sort
  end
end
