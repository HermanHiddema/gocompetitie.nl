require "test_helper"

class SeasonTest < ActiveSupport::TestCase
  test "new seasons start as a draft" do
    assert Season.new.draft?
    assert Season.create!(name: "Voorjaar 2029").draft?
  end

  test "there can be at most one active season" do
    season = Season.create!(name: "Voorjaar 2029")

    season.phase = :active
    assert_not season.valid?

    seasons(:current).update!(phase: :finished)
    assert season.valid?
  end

  test "the current season is the active one, or the last finished one" do
    assert_equal seasons(:current), Season.current

    seasons(:current).update!(phase: :draft)
    assert_equal seasons(:previous), Season.current
  end

  test "the current season fallback is the most recently finished season" do
    current = seasons(:current)
    previous = seasons(:previous)
    current.update!(phase: :draft)
    travel 1.second do
      previous.update!(phase: :draft)
      previous.start!
      previous.finish!
    end

    assert_equal previous, Season.current
  end

  test "finishing a season sets the unplayed games to 0-0" do
    season = seasons(:current)
    game = games(:unplayed)

    assert_equal 1, season.unplayed_games.count

    season.finish!

    assert season.finished?
    assert_not season.editable?
    assert_equal "0-0", game.reload.result
    assert_empty season.unplayed_games
  end

  test "finishing a season deletes the participants without games" do
    season = seasons(:current)
    playing = participants(:amsterdam_1)
    gameless = season.participants.create!(firstname: "Speler", lastname: "Zonder")

    assert_includes season.gameless_participants, gameless
    assert_not_includes season.gameless_participants, playing

    season.finish!

    assert_not Participant.exists?(gameless.id)
    assert Participant.exists?(playing.id)
  end

  test "starting a season requires a draft" do
    season = seasons(:current)

    assert_raises(ActiveRecord::RecordInvalid) { season.start! }

    season.update!(phase: :finished)
    assert_raises(ActiveRecord::RecordInvalid) { season.start! }
  end

  test "finishing a season requires it to be active" do
    season = Season.create!(name: "Najaar 2028")

    assert_raises(ActiveRecord::RecordInvalid) { season.finish! }
  end

  test "new seasons default to a three stone handicap adjustment" do
    assert_equal 3, Season.new.handicap_adjustment
  end

  test "handicap adjustment is optional and limited to valid stone counts" do
    season = seasons(:current)

    season.handicap_adjustment = nil
    assert season.valid?
    assert_not season.handicaps?

    season.handicap_adjustment = 10
    assert_not season.valid?

    season.handicap_adjustment = 0
    assert season.valid?
    assert season.handicaps?
  end

  test "the slug is derived from the name" do
    season = Season.create!(name: "Voorjaar 2027")

    assert_equal "voorjaar-2027", season.slug
  end

  test "the slug must not be blank" do
    season = Season.new(name: "!!!")

    assert_not season.valid?
    assert season.errors.added?(:slug, :blank)
  end

  test "leagues are created with the traditional names" do
    season = Season.create!(name: "Najaar 2027")
    season.create_leagues(3)

    assert_equal ["Hoofdklasse", "Eerste klasse", "Tweede klasse"], season.leagues.ordered.map(&:name)
    assert_equal [0, 1, 2], season.leagues.ordered.map(&:position)
  end

  test "results list team players first and reserves last" do
    season = seasons(:current)
    reserves = 2.times.map do |index|
      season.participants.create!(firstname: "Reserve#{index}", lastname: "Speler", rating: 1800, club: clubs(:amsterdam))
    end
    games(:board_three).update!(home_player: reserves.first, away_player: reserves.second)

    lines = season.results

    assert_equal "; Amsterdam 1", lines.first
    assert_equal ["; Amsterdam 1", "; Utrecht 1", "; Rotterdam 1", "; Reserves"], lines.grep(/\A;/)
    assert lines.last(2).any? { |line| line.include?("Reserve0") }
  end

  test "players can be imported from an EGD export" do
    season = Season.create!(name: "Najaar 2028")

    file = Tempfile.new(["egd", ".json"])
    file.write({ players: [{ "Pin_Player" => "12345678", "Real_Name" => "Jan", "Real_Last_Name" => "Jansen",
                              "Gor" => "1850", "Grade" => "2k", "Club" => "Tstv" }] }.to_json)
    file.close

    assert_difference -> { season.participants.count }, 1 do
      season.upsert_players(file.path)
    end

    participant = season.participants.last
    assert_equal "Jan Jansen", participant.fullname
    assert_equal 1850, participant.rating
    assert_equal "2k", participant.rank
    assert_equal "Tstv", participant.club.abbrev
  ensure
    file&.unlink
  end

  test "statistics count what takes part in the season" do
    season = seasons(:current)

    # Both leagues and all three teams count, every club fields a team and
    # seven participants have a game played or scheduled.
    assert_equal({ leagues: 2, clubs: 3, teams: 3, participants: 7 }, season.statistics)
    assert_equal({ leagues: 0, clubs: 0, teams: 0, participants: 0 }, seasons(:previous).statistics)
  end

  test "statistics for multiple seasons are grouped by season" do
    statistics = Season.statistics_for(Season.where(id: [seasons(:current).id, seasons(:previous).id]))

    assert_equal({ leagues: 2, clubs: 3, teams: 3, participants: 7 }, statistics.fetch(seasons(:current).id))
    assert_equal({ leagues: 0, clubs: 0, teams: 0, participants: 0 }, statistics.fetch(seasons(:previous).id))
  end

  test "statistics return preloaded values when available" do
    seasons = Season.where(id: [seasons(:current).id, seasons(:previous).id]).to_a

    Season.preload_statistics(seasons)

    seasons_by_id = seasons.index_by(&:id)

    assert_equal({ leagues: 2, clubs: 3, teams: 3, participants: 7 }, seasons_by_id.fetch(seasons(:current).id).statistics)
    assert_equal({ leagues: 0, clubs: 0, teams: 0, participants: 0 }, seasons_by_id.fetch(seasons(:previous).id).statistics)
  end
end
