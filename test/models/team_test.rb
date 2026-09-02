require "test_helper"

class TeamTest < ActiveSupport::TestCase
  test "score and points are summed over both colors" do
    assert_equal 1, teams(:amsterdam).score
    assert_equal 2, teams(:amsterdam).points
    assert_equal 0, teams(:utrecht).score
    assert_equal 1, teams(:utrecht).points
  end

  test "matches include home and away matches" do
    assert_equal 2, teams(:utrecht).matches.count
  end

  test "unplayed matches are counted" do
    assert_equal 0, teams(:amsterdam).unplayed_matches
    assert_equal 1, teams(:utrecht).unplayed_matches
  end

  test "a team requires a name, abbreviation, club and league" do
    team = Team.new

    assert_not team.valid?
    assert_equal %i[club league name abbrev].sort, team.errors.attribute_names.sort
  end
end
