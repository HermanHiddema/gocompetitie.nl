require "test_helper"

class SeasonSelectionTest < ActionDispatch::IntegrationTest
  test "the front page redirects to the most recent season" do
    get root_url

    assert_redirected_to season_url(seasons(:current))
    follow_redirect!
    assert_select "h1", "Stand #{seasons(:current).name}"
  end

  test "a season path selects that season" do
    get season_url(seasons(:previous))

    assert_select "h1", "Stand Najaar 2025"
    assert_select "a[href=?]", teams_path(season_slug: seasons(:previous).slug)
  end

  test "a season path selects that season on the other pages" do
    get teams_url(season_slug: seasons(:previous).slug)

    assert_response :success
    assert_select "footer", /Najaar 2025/
  end

  test "the most recent season is shown without a season path" do
    get teams_url

    assert_response :success
    assert_select "footer", /Voorjaar 2026/
  end
end
