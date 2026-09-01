require "test_helper"

class GameTest < ActiveSupport::TestCase
  setup do
    @game = games(:board_one)
    @unplayed = games(:unplayed)
  end

  test "result is formatted from the stored points" do
    assert_equal "1-0", @game.result
    assert_equal "0-1", games(:board_two).result
    assert_equal "?-?", @unplayed.result
  end

  test "result assignment stores points and forfeit reason" do
    @unplayed.result = "0-1!"

    assert_equal 0, @unplayed.black_points
    assert_equal 2, @unplayed.white_points
    assert @unplayed.forfeit?
    assert_equal "0-1!", @unplayed.result
  end

  test "result assignment of a jigo" do
    @unplayed.result = "½-½"

    assert_equal 1, @unplayed.black_points
    assert_equal 1, @unplayed.white_points
    assert_in_delta 0.5, @unplayed.black_score
    assert_equal "=", @unplayed.black_result
  end

  test "unknown result clears the game" do
    @game.result = "unknown"

    assert_nil @game.black_points
    assert_nil @game.white_points
    assert @game.unplayed?
  end

  test "scores and result symbols" do
    assert_equal 1, @game.black_score
    assert_equal 0, @game.white_score
    assert_equal "+", @game.black_result
    assert_equal "-", @game.white_result
    assert_equal "?", @unplayed.black_result
  end

  test "swapping colors swaps players and points" do
    black, white = @game.black_player, @game.white_player
    @game.swap_colors

    assert_equal white, @game.reload.black_player
    assert_equal black, @game.white_player
    assert_equal 0, @game.black_points
    assert_equal 2, @game.white_points
  end

  test "color of a player" do
    assert_equal :black, @game.color_of(@game.black_player)
    assert_equal :white, @game.color_of(@game.white_player)
    assert_nil @game.color_of(participants(:rotterdam_1))
  end

  test "rating change rewards beating a stronger player" do
    upset = games(:board_two) # white (weaker) wins

    assert_operator upset.white_rating_change, :>, 0.5
    assert_in_delta(-upset.white_rating_change, upset.black_rating_change, 0.0001)
  end

  test "expected scores of both players add up to one" do
    assert_in_delta 1.0, @game.black_score_exp + @game.white_score_exp, 0.0001
  end

  test "forfeited and unplayed games do not change ratings" do
    assert_equal 0, @unplayed.black_rating_change

    @game.update!(reason: "!")
    assert_equal 0, @game.black_rating_change
  end
end
