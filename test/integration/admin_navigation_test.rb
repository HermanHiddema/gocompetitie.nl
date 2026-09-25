require "test_helper"

class AdminNavigationTest < ActionDispatch::IntegrationTest
  test "the navigation has no admin links for visitors" do
    get season_url(seasons(:current))

    assert_response :success
    assert_select "header nav a", text: "Spelers", count: 0
    assert_select "header nav a", text: "Personen", count: 0
  end

  test "the navigation has no admin links for ordinary users" do
    sign_in_as users(:member)

    get season_url(seasons(:current))

    assert_response :success
    assert_select "header nav a", text: "Spelers", count: 0
    assert_select "header nav a", text: "Personen", count: 0
  end

  test "the navigation links admins to the participants of the season and to the people" do
    sign_in_as users(:admin)

    get season_url(seasons(:previous))

    assert_response :success
    assert_select "header nav a[href=?]", participants_path(season_slug: seasons(:previous).slug), text: "Spelers"
    assert_select "header nav a[href=?]", people_path, text: "Personen"
  end
end
