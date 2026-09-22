require "test_helper"

# == Schema Information
#
# Table name: seasons
#
#  id                  :bigint           not null, primary key
#  handicap_adjustment :integer          default(3)
#  information         :text
#  name                :string           not null
#  phase               :string           default("draft"), not null
#  slug                :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_seasons_on_active_phase  (phase) UNIQUE WHERE ((phase)::text = 'active'::text)
#  index_seasons_on_phase         (phase)
#  index_seasons_on_slug          (slug) UNIQUE
#
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

  test "finishing a season deletes the participants without games, except team members" do
    season = seasons(:current)
    playing = season.participants.create!(firstname: "Speler", lastname: "Met_partij")
    team_member = participants(:rotterdam_3)
    gameless = season.participants.create!(firstname: "Speler", lastname: "Zonder")
    games(:board_one).update!(home_player: playing)

    assert_includes season.gameless_participants, gameless
    assert_not_includes season.gameless_participants, playing
    assert_not_includes season.gameless_participants, team_member

    season.finish!

    assert_not Participant.exists?(gameless.id)
    assert Participant.exists?(playing.id)
    assert Participant.exists?(team_member.id)
  end

  test "cancelling a season leaves the unplayed games unplayed and has no champion" do
    season = seasons(:current)
    game = games(:unplayed)

    season.cancel!

    assert season.cancelled?
    assert_not season.editable?
    assert_nil season.champion
    assert_nil game.reload.home_points
    assert_equal 1, season.unplayed_games.count
  end

  test "cancelling a season deletes the participants without games, except team members" do
    season = seasons(:current)
    playing = season.participants.create!(firstname: "Speler", lastname: "Met_partij")
    team_member = participants(:rotterdam_3)
    gameless = season.participants.create!(firstname: "Speler", lastname: "Zonder")
    games(:board_one).update!(home_player: playing)

    season.cancel!

    assert_not Participant.exists?(gameless.id)
    assert Participant.exists?(playing.id)
    assert Participant.exists?(team_member.id)
  end

  test "cancelling a season requires it to be active" do
    season = Season.create!(name: "Najaar 2028")

    assert_raises(ActiveRecord::RecordInvalid) { season.cancel! }
  end

  test "the current season fallback also considers cancelled seasons" do
    seasons(:current).cancel!

    assert_equal seasons(:current), Season.current
  end

  test "starting a season requires a draft" do
    season = seasons(:current)

    assert_raises(ActiveRecord::RecordInvalid) { season.start! }

    season.update!(phase: :finished)
    assert_raises(ActiveRecord::RecordInvalid) { season.start! }

    season.update!(phase: :cancelled)
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

  test "players are imported from the EGD, by default the recently active Dutch ones" do
    season = Season.create!(name: "Najaar 2029")
    client = FakeEgdClient.new([
      egd_player(pin: 12345678, first_name: "Jan", last_name: "Jansen", club: "Tstv", grade: "2k",
        rating: 1850, last_appearance: 1.year.ago.to_date.to_s),
      egd_player(pin: 22222222, first_name: "Piet", last_name: "Pietersen", club: "Tstv", grade: "5k",
        rating: 1400, last_appearance: 6.years.ago.to_date.to_s),
      egd_player(pin: 33333333, first_name: "Klaas", last_name: "Klaassen", club: "Tstv", grade: "1d",
        rating: 2100, last_appearance: nil)
    ])

    imported = nil
    assert_difference -> { season.participants.count }, 1 do
      imported = season.import_egd_players(client: client)
    end

    assert_equal 1, imported
    assert_equal({ countryCode: "NL" }, client.filter)

    participant = season.participants.sole
    assert_equal "Jan Jansen", participant.fullname
    assert_equal 1850, participant.rating
    assert_equal "2k", participant.rank
    assert_equal "12345678", participant.egd_pin
    assert_equal "Tstv", participant.club.abbrev
  end

  test "importing players from the EGD twice updates them instead of adding them again" do
    season = Season.create!(name: "Najaar 2029")
    player = egd_player(pin: 12345678, first_name: "Jan", last_name: "Jansen", club: "Tstv", grade: "2k",
      rating: 1850, last_appearance: 1.year.ago.to_date.to_s)
    season.import_egd_players(client: FakeEgdClient.new([player]))

    assert_no_difference -> { season.participants.count } do
      season.import_egd_players(client: FakeEgdClient.new([player.merge("rating" => 1900, "grade" => "1k")]))
    end

    participant = season.participants.sole
    assert_equal 1900, participant.rating
    assert_equal "1k", participant.rank
  end

  test "all players of a country are imported when no period is given" do
    season = Season.create!(name: "Najaar 2029")
    client = FakeEgdClient.new([
      egd_player(pin: 12345678, first_name: "Jan", last_name: "Jansen", club: "Tstv", grade: "2k",
        rating: 1850, last_appearance: 20.years.ago.to_date.to_s)
    ])

    assert_difference -> { season.participants.count }, 1 do
      season.import_egd_players(country_code: "DE", years: nil, client: client)
    end

    assert_equal({ countryCode: "DE" }, client.filter)
  end

  test "invalid activity cutoffs are rejected before importing" do
    season = Season.create!(name: "Najaar 2029")
    client = RejectingEgdClient.new

    ["four", -1, 0].each do |years|
      error = assert_raises(Egd::Error) do
        season.import_egd_players(years: years, client: client)
      end

      assert_equal "YEARS moet een positief aantal jaren zijn", error.message
    end
  end

  test "the champion is the winner of the highest league of a finished season" do
    season = seasons(:current)

    # While the season is being played the standings can still change.
    assert_nil season.champion

    season.finish!

    assert_equal teams(:amsterdam), season.champion
    assert_nil seasons(:previous).champion
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

  test "statistics preloading also preloads the champion for finished seasons" do
    season = seasons(:current)
    season.finish!
    seasons = Season.where(id: [season.id]).to_a

    Season.preload_statistics(seasons)

    assert_equal teams(:amsterdam), seasons.first.champion
  end

  private
    # Stands in for Egd::Client so the tests do not reach the European Go Database.
    class FakeEgdClient
      attr_reader :filter

      def initialize(players)
        @players = players
      end

      def players(filter: {})
        @filter = filter
        @players
      end
    end

    class RejectingEgdClient
      def players(**)
        raise "players should not be fetched for invalid YEARS"
      end
    end

    def egd_player(pin:, first_name:, last_name:, club:, grade:, rating:, last_appearance:)
      { "pin" => pin, "firstName" => first_name, "lastName" => last_name, "countryCode" => "NL",
        "club" => club, "grade" => grade, "rating" => rating, "lastAppearance" => last_appearance }
    end
end
