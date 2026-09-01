require "test_helper"

class MatchesControllerTest < ActionDispatch::IntegrationTest
  setup { @match = matches(:amsterdam_utrecht) }

  test "index lists the matches of the season grouped by date" do
    get matches_url

    assert_response :success
    assert_select "h1", "Wedstrijden"
  end

  test "show renders the games of a match" do
    get match_url(@match)

    assert_response :success
    assert_select "h1", /Amsterdam 1/
  end

  test "new requires authentication" do
    get new_match_url
    assert_redirected_to new_session_url
  end

  test "signed in users can schedule a match, which fills the boards" do
    sign_in_as users(:member)

    assert_difference -> { Match.count }, 1 do
      post matches_url, params: { match: { league_id: leagues(:top).id, black_team_id: teams(:amsterdam).id,
        white_team_id: teams(:rotterdam).id, venue_id: venues(:amsterdam).id,
        playing_date: "2026-04-01", playing_time: "20:00" } }
    end

    match = Match.last
    assert_redirected_to edit_match_url(match)
    assert_equal 3, match.games.count
  end

  test "edit fills up the boards and lists selectable players" do
    sign_in_as users(:member)
    @match.games.destroy_all

    assert_difference -> { @match.games.count }, 3 do
      get edit_match_url(@match)
    end

    assert_response :success
  end

  test "edit can list all participants of the season" do
    sign_in_as users(:member)

    get edit_match_url(@match, all: 1)

    assert_response :success
    assert_select "option", text: /Rotterdam/
  end

  test "signed in users can enter results" do
    sign_in_as users(:member)
    game = @match.games.find_by(board_number: 1)

    patch match_url(@match), params: { match: { playing_time: "19:00", games_attributes: {
      "0" => { id: game.id, black_id: game.black_id, white_id: game.white_id, result: "0-1!" } } } }

    assert_redirected_to match_url(@match)
    assert_equal "0-1!", game.reload.result
    assert game.forfeit?
    assert_equal "19:00", @match.reload.playing_time
  end

  test "signed in users can delete a match" do
    sign_in_as users(:member)

    assert_difference -> { Match.count }, -1 do
      delete match_url(@match)
    end

    assert_redirected_to matches_url
  end
end
