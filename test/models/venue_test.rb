require "test_helper"

# == Schema Information
#
# Table name: venues
#
#  id           :bigint           not null, primary key
#  address      :string           not null
#  city         :string           not null
#  info         :text
#  name         :string           not null
#  playing_day  :integer          not null
#  playing_time :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  club_id      :bigint
#
# Indexes
#
#  index_venues_on_club_id  (club_id)
#
# Foreign Keys
#
#  fk_rails_...  (club_id => clubs.id)
#
class VenueTest < ActiveSupport::TestCase
  test "the playing day is translated to a Dutch day name" do
    assert_equal "dinsdag", venues(:amsterdam).playing_day_name
  end

  test "a venue requires name, address, city and playing details, but no club" do
    venue = Venue.new

    assert_not venue.valid?
    assert_equal %i[name address city playing_time playing_day].sort, venue.errors.attribute_names.sort
  end

  test "a venue does not need a club" do
    venue = venues(:to_be_determined)

    assert_nil venue.club
    assert_predicate venue, :valid?
  end

  test "a venue with matches cannot be destroyed" do
    venue = venues(:amsterdam)

    assert_not venue.destroy
    assert_predicate venue.errors[:base], :any?
  end
end
