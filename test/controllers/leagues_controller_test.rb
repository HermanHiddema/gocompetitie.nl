require "test_helper"

class LeaguesControllerTest < ActionDispatch::IntegrationTest
  test "show renders standings, matches, teams" do
    get league_url(leagues(:top))

    assert_response :success
    assert_select "h1", "Hoofdklasse"
    assert_select "table.table-auto"
    assert_select "table.table-fixed", count: 0
    assert_select "table span.whitespace-nowrap"
    assert_select "div.overflow-x-auto"
  end

  test "show lists the teams alphabetically" do
    teams(:amsterdam).update!(name: "Zwolle 1")

    get league_url(leagues(:top))

    names = css_select("#teams a").map(&:text)
    assert_equal names.sort, names
    assert_equal "Zwolle 1", names.last
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
    sign_in_as users(:admin)
    season = seasons(:current)
    season.update!(phase: :draft)

    assert_difference -> { League.count }, 1 do
      post leagues_url, params: { league: { name: "Tweede klasse", position: 2, season_id: season.id } }
    end

    assert_redirected_to league_url(League.last)
  end

  test "leagues can no longer be added once the season has started" do
    sign_in_as users(:admin)
    season = seasons(:current)

    get new_league_url
    assert_redirected_to season_url(season)

    assert_no_difference -> { League.count } do
      post leagues_url, params: { league: { name: "Tweede klasse", position: 2 } }
    end

    assert_redirected_to season_url(season)
  end

  test "finished seasons can no longer be changed" do
    sign_in_as users(:admin)
    league = leagues(:top)
    league.season.update!(phase: :finished)

    patch league_url(league), params: { league: { name: "Gewijzigd", position: league.position } }
    assert_redirected_to season_url(league.season)
    assert_equal "Hoofdklasse", league.reload.name

    assert_no_difference -> { League.count } do
      delete league_url(league)
    end

    assert_redirected_to season_url(league.season)
  end
end
