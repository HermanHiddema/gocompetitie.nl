require "test_helper"

class SearchIndexingTest < ActionDispatch::IntegrationTest
  test "the pages without personal details may be indexed" do
    [seasons_url, season_url(seasons(:current)), matches_url].each do |url|
      get url

      assert_response :success
      assert_select "meta[name=robots]", count: 0
      assert_nil response.headers["X-Robots-Tag"]
    end
  end

  test "the pages with personal details are kept out of search indexes" do
    [clubs_url, club_url(clubs(:amsterdam)), venues_url, venue_url(venues(:amsterdam)),
     teams_url, team_url(teams(:amsterdam)), match_url(matches(:amsterdam_utrecht)), games_url,
     league_url(leagues(:top))].each do |url|
      get url

      assert_response :success
      assert_select "meta[name=robots][content=?]", "noindex, nofollow"
      assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
    end
  end

  test "the text exports are not indexed" do
    get league_url(leagues(:top), format: :text)

    assert_response :success
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end
end
