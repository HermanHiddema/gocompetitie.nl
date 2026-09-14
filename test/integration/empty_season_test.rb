require "test_helper"

class EmptySeasonTest < ActionDispatch::IntegrationTest
  setup { Season.destroy_all }

  test "the front page falls back to the season list without a season" do
    get root_url

    assert_redirected_to seasons_url
  end

  test "the public pages render without a season" do
    [seasons_url, matches_url, teams_url, participants_url, games_url, venue_url(venues(:amsterdam))].each do |url|
      get url
      assert_response :success
    end
  end
end
