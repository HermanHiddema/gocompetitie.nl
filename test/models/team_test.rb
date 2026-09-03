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

  test "the league of a team with matches cannot be changed" do
    team = teams(:amsterdam)

    assert_not team.update(league: leagues(:first))
    assert_includes team.errors.attribute_names, :league
  end

  test "team members must have unique board numbers and participants" do
    team = teams(:amsterdam)
    team.assign_attributes(team_members_attributes: {
      "0" => { id: team_members(:amsterdam_2).id, board_number: 1, participant_id: participants(:amsterdam_2).id },
      "1" => { id: team_members(:amsterdam_3).id, participant_id: participants(:amsterdam_1).id }
    })

    assert_not team.valid?
    assert_equal 2, team.errors.where(:base).count
  end
end
