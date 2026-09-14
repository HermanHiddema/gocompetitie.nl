require "test_helper"

class SeasonsControllerTest < ActionDispatch::IntegrationTest
  test "index lists all seasons" do
    get seasons_url

    assert_response :success
    assert_select "a", text: "Voorjaar 2026"
  end

  test "show renders the standings of the season" do
    get season_url(seasons(:current))

    assert_response :success
    assert_select "h1", "Stand Voorjaar 2026"
    assert_select "table"
  end

  test "the front page redirects to the most recent season" do
    get root_url

    assert_redirected_to season_url(Season.recent.first)
  end

  test "show renders the EGD result list as text" do
    get season_url(seasons(:current), format: :text)

    assert_response :success
    assert_match "; Amsterdam 1", response.body
  end

  test "only admins can create seasons" do
    sign_in_as users(:member)
    get new_season_url
    assert_response :unauthorized

    sign_in_as users(:admin)
    assert_difference -> { Season.count }, 1 do
      post seasons_url, params: { season: { name: "Najaar 2026" } }
    end
  end
end
