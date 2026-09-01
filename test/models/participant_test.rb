require "test_helper"

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
    ranks = [ "5k", "1k", "1d", "5d", "1p" ].map do |rank|
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

  test "rating change adds up the game rating changes" do
    assert_in_delta @participant.black_games.played.sum(&:black_rating_change), @participant.rating_change, 0.0001
    assert_match(/%\z/, @participant.rating_performance)
  end

  test "person attributes can be copied onto a participant" do
    participant = Participant.new(season: seasons(:current), person: people(:anna))
    participant.copy_person_attributes

    assert_equal "Anna", participant.firstname
    assert_equal clubs(:amsterdam), participant.club
  end
end
