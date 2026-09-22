require "test_helper"

# == Schema Information
#
# Table name: matches
#
#  id           :bigint           not null, primary key
#  playing_date :date
#  playing_time :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  away_team_id :bigint           not null
#  home_team_id :bigint           not null
#  league_id    :bigint           not null
#  venue_id     :bigint
#
# Indexes
#
#  index_matches_on_away_team_id          (away_team_id)
#  index_matches_on_home_team_id          (home_team_id)
#  index_matches_on_league_and_team_pair  (league_id, LEAST(home_team_id, away_team_id), GREATEST(home_team_id, away_team_id)) UNIQUE
#  index_matches_on_league_id             (league_id)
#  index_matches_on_venue_id              (venue_id)
#
# Foreign Keys
#
#  fk_rails_...  (away_team_id => teams.id)
#  fk_rails_...  (home_team_id => teams.id)
#  fk_rails_...  (league_id => leagues.id)
#  fk_rails_...  (venue_id => venues.id)
#
class MatchTest < ActiveSupport::TestCase
  setup do
    @match = matches(:amsterdam_utrecht)
    @unplayed = matches(:utrecht_rotterdam)
  end

  test "board points are counted per won board" do
    assert_equal 2, @match.home_points
    assert_equal 1, @match.away_points
    assert_equal "2-1", @match.result
  end

  test "match score is awarded to the team with most board points" do
    assert_equal 1, @match.home_score
    assert_equal 0, @match.away_score
  end

  test "a match without played games has no result" do
    assert_not @unplayed.played?
    assert_nil @unplayed.home_points
    assert_equal "?-?", @unplayed.result
  end

  test "games are created for matching board numbers after create" do
    match = Match.create!(league: leagues(:top), home_team: teams(:amsterdam), away_team: teams(:rotterdam))

    assert_equal 3, match.games.count
    assert_equal participants(:amsterdam_1), match.games.find_by(board_number: 1).home_player
    assert_equal participants(:rotterdam_1), match.games.find_by(board_number: 1).away_player
  end

  test "swapping sides swaps teams and game results" do
    @match.swap_sides
    @match.reload

    assert_equal teams(:utrecht), @match.home_team
    assert_equal teams(:amsterdam), @match.away_team
    assert_equal 1, @match.home_points
    assert_equal 2, @match.away_points
  end

  test "finding a match by teams ignores home and away" do
    assert_equal @match, Match.find_by_teams(teams(:utrecht), teams(:amsterdam))
    assert_nil Match.find_by_teams(teams(:amsterdam), nil)
  end

  test "opponent of a team" do
    assert_equal teams(:utrecht), @match.opponent(teams(:amsterdam))
    assert_equal teams(:amsterdam), @match.opponent(teams(:utrecht))
    assert_nil @match.opponent(teams(:rotterdam))
  end
end
