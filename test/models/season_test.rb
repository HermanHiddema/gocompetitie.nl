require "test_helper"

class SeasonTest < ActiveSupport::TestCase
  test "the slug is derived from the name" do
    season = Season.create!(name: "Voorjaar 2027")

    assert_equal "voorjaar-2027", season.slug
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
    games(:board_three).update!(black_player: reserves.first, white_player: reserves.second)

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
end
