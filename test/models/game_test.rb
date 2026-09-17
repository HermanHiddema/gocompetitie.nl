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

    assert_equal 0, @unplayed.home_points
    assert_equal 2, @unplayed.away_points
    assert @unplayed.forfeit?
    assert_equal "0-1!", @unplayed.result
  end

  test "result assignment of a jigo" do
    @unplayed.result = "½-½"

    assert_equal 1, @unplayed.home_points
    assert_equal 1, @unplayed.away_points
    assert_in_delta 0.5, @unplayed.home_score
    assert_equal "=", @unplayed.home_result
  end

  test "unknown result clears the game" do
    @game.result = "unknown"

    assert_nil @game.home_points
    assert_nil @game.away_points
    assert @game.unplayed?
  end

  test "scores and result symbols" do
    assert_equal 1, @game.home_score
    assert_equal 0, @game.away_score
    assert_equal "+", @game.home_result
    assert_equal "-", @game.away_result
    assert_equal "?", @unplayed.home_result
  end

  test "swapping sides swaps players and points" do
    home, away = @game.home_player, @game.away_player
    @game.swap_sides

    assert_equal away, @game.reload.home_player
    assert_equal home, @game.away_player
    assert_equal 0, @game.home_points
    assert_equal 2, @game.away_points
  end

  test "side of a player" do
    assert_equal :home, @game.side_of(@game.home_player)
    assert_equal :away, @game.side_of(@game.away_player)
    assert_nil @game.side_of(participants(:rotterdam_1))
  end

  test "without a handicap the home team plays black on the odd boards" do
    assert_equal 0, @game.handicap
    assert_equal :black, @game.home_color
    assert_equal :white, @game.away_color
    assert_equal @game.home_player, @game.black_player
    assert_equal @game.away_player, @game.white_player

    second = games(:board_two)
    assert_equal :white, second.home_color
    assert_equal second.away_player, second.black_player
  end

  test "with a handicap the weaker player plays black" do
    @game.handicap = 2 # home player is the stronger one

    assert_equal :white, @game.home_color
    assert_equal @game.away_player, @game.black_player
    assert_equal @game.home_player, @game.white_player

    second = games(:board_two) # even board, so without a handicap the home player is white
    second.away_player.rating = second.home_player.rating + 400
    second.handicap = 1
    assert_equal :black, second.home_color
  end

  test "color and result of a player" do
    assert_equal :black, @game.color_of(@game.home_player)
    assert_equal :white, @game.color_of(@game.away_player)
    assert_nil @game.color_of(participants(:rotterdam_1))

    assert_equal "+", @game.black_result
    assert_equal "-", @game.white_result
  end

  test "rating change rewards beating a stronger player" do
    upset = games(:board_two) # the away (weaker) player wins

    assert_operator upset.away_rating_change, :>, 0.5
    assert_in_delta(-upset.away_rating_change, upset.home_rating_change, 0.0001)
  end

  test "a handicap credits the weaker player with 100 rating points per stone" do
    @game.handicap = 3 # home player is the stronger one, so the away player is black

    assert_equal @game.home_rating, @game.home_handicap_rating
    assert_equal @game.away_rating + 300, @game.away_handicap_rating
  end

  test "a handicap evens out the expected scores" do
    assert_operator @game.away_score_exp, :<, 0.5 # the away player is 100 points weaker

    @game.handicap = 1 # one stone compensates those 100 points

    assert_in_delta 0.5, @game.home_score_exp, 0.0001
    assert_in_delta 0.5, @game.away_score_exp, 0.0001
  end

  test "expected scores of both players add up to one" do
    assert_in_delta 1.0, @game.home_score_exp + @game.away_score_exp, 0.0001
  end

  test "forfeited and unplayed games do not change ratings" do
    assert_equal 0, @unplayed.home_rating_change

    @game.update!(reason: "!")
    assert_equal 0, @game.home_rating_change
  end

  test "a result without points is not a rated game" do
    @game.result = "0-0"

    assert @game.forfeit?
    assert_equal 0, @game.home_rating_change
  end

  test "handicap defaults to the rating difference minus 300, rounded half down" do
    @game.home_player.rating = 2350
    @game.away_player.rating = 2000
    assert_equal 0, @game.default_handicap # 0.5 rounds down

    @game.away_player.rating = 1900
    assert_equal 1, @game.default_handicap # 1.5 rounds down

    @game.away_player.rating = 1800
    assert_equal 2, @game.default_handicap # 2.5 rounds down

    @game.away_player.rating = 2300
    assert_equal 0, @game.default_handicap

    @unplayed.home_player.rating = nil
    assert_equal 0, @unplayed.default_handicap
  end

  test "an entered handicap overrides the default handicap" do
    @game.handicap = 4

    assert_equal 4, @game.handicap
    assert_equal 4, @game.entered_handicap

    @game.handicap = nil
    assert_equal @game.default_handicap, @game.handicap
    assert_nil @game.entered_handicap
  end

  test "handicaps outside the allowed range are invalid" do
    @game.handicap = 10
    assert_not @game.valid?

    @game.handicap = 2
    assert @game.valid?
  end

  test "egd handicap lists the color of the player" do
    @game.handicap = 3

    assert_equal "/b3", @game.egd_handicap(:black)
    assert_equal "/w3", @game.egd_handicap(:white)
  end

  test "board numbers are required, limited to the boards of a match and unique" do
    game = matches(:amsterdam_utrecht).games.build

    assert_not game.valid?

    game.board_number = Match::BOARD_COUNT + 1
    assert_not game.valid?

    game.board_number = 1
    assert_not game.valid?
  end

  test "players must be unique across the match" do
    duplicate_game = @game.match.games.build(board_number: 2, home_player: @game.home_player, away_player: participants(:utrecht_2))

    assert_not duplicate_game.valid?
    assert_includes duplicate_game.errors[:home_player], "must be unique in the match"
  end

  test "players must play in the season of the match" do
    guest = Season.create!(name: "Najaar 2029").participants.create!(firstname: "Gast", lastname: "Speler", rating: 1800)
    @unplayed.home_player = guest

    assert_not @unplayed.valid?
  end
end
