require "test_helper"

class LeaguesControllerTest < ActionDispatch::IntegrationTest
  test "the root page shows the standings of the current season" do
    get root_url

    assert_response :success
    assert_select "h1", /Stand/
    assert_select "table"
  end

  test "show renders standings, matches, teams" do
    get league_url(leagues(:top))

    assert_response :success
    assert_select "h1", "Hoofdklasse"
  end

  test "show renders the EGD result list as text" do
    get league_url(leagues(:top), format: :text)

    assert_response :success
    assert_match "; Amsterdam 1", response.body
  end

  test "editing requires authentication" do
    get edit_league_url(leagues(:top))
    assert_redirected_to new_session_url
  end

  test "signed in users can create a league" do
    sign_in_as users(:member)

    assert_difference -> { League.count }, 1 do
      post leagues_url, params: { league: { name: "Tweede klasse", position: 2, season_id: seasons(:current).id } }
    end

    assert_redirected_to league_url(League.last)
  end
end
