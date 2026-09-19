require "test_helper"

class SearchIndexingTest < ActionDispatch::IntegrationTest
  test "the pages without personal details may be indexed" do
    [ seasons_url, season_url(seasons(:current)), league_url(leagues(:top)), matches_url ].each do |url|
      get url

      assert_response :success
      assert_select "meta[name=robots]", count: 0
    end
  end

  test "the pages with personal details are kept out of search indexes" do
    [ clubs_url, club_url(clubs(:amsterdam)), venues_url, venue_url(venues(:amsterdam)),
      teams_url, team_url(teams(:amsterdam)), match_url(matches(:amsterdam_utrecht)), games_url ].each do |url|
      get url

      assert_response :success
      assert_select "meta[name=robots][content=?]", "noindex, nofollow"
    end
  end

  test "the text exports are not indexed" do
    get league_url(leagues(:top), format: :text)

    assert_response :success
    assert_no_match "robots", response.body
  end
end
