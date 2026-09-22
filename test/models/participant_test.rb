require "test_helper"

# == Schema Information
#
# Table name: participants
#
#  id         :bigint           not null, primary key
#  egd_pin    :string
#  firstname  :string           not null
#  lastname   :string           not null
#  rank       :integer
#  rating     :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  club_id    :bigint
#  person_id  :bigint
#  season_id  :bigint           not null
#
# Indexes
#
#  index_participants_on_club_id    (club_id)
#  index_participants_on_person_id  (person_id)
#  index_participants_on_season_id  (season_id)
#
# Foreign Keys
#
#  fk_rails_...  (club_id => clubs.id)
#  fk_rails_...  (person_id => people.id)
#  fk_rails_...  (season_id => seasons.id)
#
class ParticipantTest < ActiveSupport::TestCase
  setup do
    @participant = participants(:amsterdam_1)
  end

  test "names strip underscores and include the rating" do
    @participant.update!(firstname: "Jan_Willem", lastname: "van_Dijk")

    assert_equal "Jan Willem van Dijk", @participant.fullname
    assert_equal "Jan Willem van Dijk (2100)", @participant.name
  end

  test "ranks are stored as sortable integers" do
    { "5k" => "5k", "1 kyu" => "1k", "3d" => "3d", "1p" => "1p", "pro" => "pro", "" => "" }.each do |input, expected|
      @participant.rank = input
      assert_equal expected, @participant.rank, "expected #{input.inspect} to become #{expected.inspect}"
    end
  end

  test "stronger ranks sort higher" do
    ranks = ["5k", "1k", "1d", "5d", "1p"].map do |rank|
      @participant.rank = rank
      @participant[:rank]
    end

    assert_equal ranks.sort, ranks
  end

  test "games include both colors" do
    assert_equal 1, @participant.games.count
    assert_equal 1, @participant.played_games.count
    assert_equal 0, participants(:rotterdam_1).played_games.count
  end

  test "rating change adds up the played home and away game changes" do
    matches(:utrecht_rotterdam).games.create!(
      board_number: 2,
      home_player: participants(:utrecht_2),
      away_player: @participant,
      home_points: 0,
      away_points: 2
    )

    participant = Participant.includes(:home_games, :away_games).find(@participant.id)
    expected = participant.home_games.select(&:played?).sum(&:home_rating_change) +
      participant.away_games.select(&:played?).sum(&:away_rating_change)

    assert_in_delta expected, participant.rating_change, 0.0001
    assert_match(/%\z/, @participant.rating_performance)
  end

  test "person attributes can be copied onto a participant" do
    participant = Participant.new(season: seasons(:current), person: people(:anna))
    participant.copy_person_attributes

    assert_equal "Anna", participant.firstname
    assert_equal clubs(:amsterdam), participant.club
  end
end
