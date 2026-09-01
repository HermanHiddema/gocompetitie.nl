require "test_helper"

class LeagueTest < ActiveSupport::TestCase
  setup do
    @league = leagues(:top)
  end

  test "round robin pairing schedules every team once against every other team" do
    teams = %w[ a b c d ]
    rounds = League.round_robin_pairing(teams)

    assert_equal 3, rounds.length
    pairs = rounds.flatten(1).map { |pair| pair.compact.sort }
    assert_equal 6, pairs.length
    assert_equal pairs.uniq.length, pairs.length
  end

  test "round robin pairing adds a bye for an odd number of teams" do
    rounds = League.round_robin_pairing(%w[ a b c ])

    assert_equal 3, rounds.length
    assert rounds.flatten(1).any? { |pair| pair.include?(nil) }
  end

  test "round robin pairing needs at least three teams" do
    assert_nil League.round_robin_pairing(%w[ a b ])
  end

  test "making a pairing creates matches for every team combination" do
    league = leagues(:first)
    %w[ Alpha Beta Gamma ].each do |name|
      league.teams.create!(name: name, abbrev: name[0, 4], club: clubs(:amsterdam), captain: people(:anna))
    end

    assert_difference -> { league.matches.count }, 3 do
      league.make_pairing
    end

    assert_difference -> { league.matches.count }, -3 do
      league.drop_pairing
    end
  end

  test "standings hold the result of the mutual match" do
    standing = @league.standing(teams(:amsterdam), teams(:utrecht))

    assert_equal matches(:amsterdam_utrecht), standing.match
    assert_equal 2, standing.points
    assert_equal "won", standing.status
    assert_equal "lost", @league.standing(teams(:utrecht), teams(:amsterdam)).status
    assert_equal "unplayed", @league.standing(teams(:utrecht), teams(:rotterdam)).status
  end

  test "teams without a mutual match have no standing" do
    assert_nil @league.standing(teams(:amsterdam), teams(:rotterdam))
  end

  test "teams are ranked by score, then board points" do
    assert_equal [ teams(:amsterdam), teams(:utrecht), teams(:rotterdam) ].map(&:name).sort,
      @league.ranked_teams.map(&:name).sort
    assert_equal teams(:amsterdam), @league.ranked_teams.first
  end

  test "results list every player grouped by team" do
    lines = @league.results

    assert_equal "; Amsterdam 1", lines.first
    assert_equal 3, lines.count { |line| line.start_with?(";") }
    assert lines.any? { |line| line.include?("Amsterdam Speler1") }
  end
end
