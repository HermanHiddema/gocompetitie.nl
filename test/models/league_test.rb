require "test_helper"

class LeagueTest < ActiveSupport::TestCase
  setup do
    @league = leagues(:top)
  end

  test "round robin pairing schedules every team once against every other team" do
    teams = %w[a b c d]
    rounds = League.round_robin_pairing(teams)

    assert_equal 3, rounds.length
    pairs = rounds.flatten(1).map { |pair| pair.compact.sort }
    assert_equal 6, pairs.length
    assert_equal pairs.uniq.length, pairs.length
  end

  test "round robin pairing adds a bye for an odd number of teams" do
    rounds = League.round_robin_pairing(%w[a b c])

    assert_equal 3, rounds.length
    assert rounds.flatten(1).any? { |pair| pair.include?(nil) }
  end

  test "round robin pairing needs at least three teams" do
    assert_nil League.round_robin_pairing(%w[a b])
  end

  test "making a pairing creates matches for every team combination" do
    league = leagues(:first)
    %w[Alpha Beta Gamma].each do |name|
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
    assert_equal [teams(:amsterdam), teams(:utrecht), teams(:rotterdam)].map(&:name).sort,
      @league.ranked_teams.map(&:name).sort
    assert_equal teams(:amsterdam), @league.ranked_teams.first
  end

  test "results list the color and handicap of every game" do
    game = games(:board_one)
    game.away_player.update!(rating: game.home_rating - 500)
    game.update!(handicap: 2) # the weaker away player takes black

    lines = @league.results

    assert lines.any? { |line| line.include?("4+/w2") }
    assert lines.any? { |line| line.include?("1-/b2") }
    assert lines.any? { |line| line.include?("2+/b0") } # even board, so the away player is black
    assert lines.any? { |line| line.include?("6+/b0") } # odd board, so the home player is black
  end

  test "tied teams are ranked by the match points of their mutual matches" do
    league = leagues(:first)
    alpha, beta, gamma, delta = create_teams(league, %w[Alpha Beta Gamma Delta])
    play(league, alpha, beta, %w[1-0 1-0 0-1])
    play(league, alpha, gamma, %w[1-0 0-1 0-1])
    play(league, beta, gamma, %w[1-0 1-0 0-1])
    play(league, gamma, delta, %w[1-0 1-0 1-0])

    assert_equal [gamma, alpha, beta, delta], league.ranked_teams
  end

  test "tied teams with equal mutual match points are ranked by their mutual board points" do
    league = leagues(:first)
    alpha, beta, gamma, delta, epsilon = create_teams(league, %w[Alpha Beta Gamma Delta Epsilon])
    play(league, alpha, beta, %w[1-0 1-0 0-1])
    play(league, alpha, gamma, [])
    play(league, alpha, delta, %w[1-0 0-1 0-1])
    play(league, beta, gamma, %w[1-0 1-0 0-1])
    play(league, beta, delta, [])
    play(league, gamma, delta, %w[1-0 1-0 0-1])
    play(league, delta, epsilon, %w[1-0 1-0 1-0])

    assert_equal [delta, beta, alpha, gamma, epsilon], league.ranked_teams
  end

  test "teams that remain tied are compared without the results of the last boards" do
    league = leagues(:first)
    alpha, beta, gamma = create_teams(league, %w[Alpha Beta Gamma])
    play(league, alpha, beta, %w[1-0 0-1 ½-½])
    play(league, alpha, gamma, %w[0-1 0-1 1-0])
    play(league, beta, gamma, %w[0-1 0-1 1-0])

    assert_equal [gamma, alpha, beta], league.ranked_teams
  end

  test "tied subgroups are recomputed from their own mutual matches" do
    league = leagues(:first)
    alpha, beta, gamma, delta, epsilon, zeta = create_teams(league, %w[Alpha Beta Gamma Delta Epsilon Zeta])
    play(league, alpha, beta, %w[1-0 1-0 0-1])
    play(league, alpha, gamma, %w[0-1 0-1 0-1])
    play(league, beta, gamma, %w[1-0])
    play(league, alpha, delta, %w[1-0 1-0])
    play(league, beta, epsilon, %w[1-0 1-0])
    play(league, gamma, zeta, %w[1-0])

    assert_equal [gamma, alpha, beta], league.ranked_teams.first(3)
  end

  test "teams without a tie breaker are all ranked" do
    league = leagues(:first)
    alpha, beta, gamma = create_teams(league, %w[Alpha Beta Gamma])
    play(league, alpha, beta, %w[½-½ ½-½ ½-½])
    play(league, alpha, gamma, %w[½-½ ½-½ ½-½])
    play(league, beta, gamma, %w[½-½ ½-½ ½-½])

    assert_equal [alpha, beta, gamma], league.ranked_teams.sort_by(&:name)
  end

  test "results list every player grouped by team" do
    lines = @league.results

    assert_equal "; Amsterdam 1", lines.first
    assert_equal 3, lines.count { |line| line.start_with?(";") }
    assert lines.any? { |line| line.include?("Amsterdam Speler1") }
  end

  test "participants list the team players and the substitutes without a team" do
    substitute = seasons(:current).participants.create!(firstname: "Invaller", lastname: "Speler", rating: 1900, club: clubs(:amsterdam))
    other_team_player = seasons(:current).participants.create!(firstname: "Andere", lastname: "Speler", rating: 1800, club: clubs(:amsterdam))
    other_team = leagues(:first).teams.create!(name: "Amsterdam 2", abbrev: "Ams2", club: clubs(:amsterdam))
    other_team.team_members.create!(participant: other_team_player, board_number: 1)
    games(:unplayed).update!(home_player: substitute, away_player: other_team_player)

    players = @league.participants.to_a

    assert_equal 10, players.length
    assert_includes players, substitute
    assert_includes players, participants(:amsterdam_1)
    assert_not_includes players, other_team_player
  end

  private
    def create_teams(league, names)
      names.map { |name| league.teams.create!(name: name, abbrev: name[0, 4], club: clubs(:amsterdam)) }
    end

    # Play a match between two teams, with one result per board, seen from the
    # first (home) team.
    def play(league, home_team, away_team, results)
      match = league.matches.create!(home_team: home_team, away_team: away_team)
      match.games.by_board.each_with_index { |game, index| game.update!(result: results[index]) }
      match
    end
end
