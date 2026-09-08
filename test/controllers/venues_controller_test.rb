require "test_helper"

class VenuesControllerTest < ActionDispatch::IntegrationTest
  test "index lists the venues" do
    get venues_url

    assert_response :success
    assert_select "a", text: "Amsterdam"
  end

  test "index only lists venues of clubs that take part in the season" do
    get venues_url(season_slug: seasons(:previous).slug)
    assert_select "a", text: "Amsterdam", count: 0

    get venues_url(season_slug: seasons(:current).slug)
    assert_select "a", text: "Amsterdam", count: 1
  end

  test "show lists the matches played at the venue" do
    get venue_url(venues(:amsterdam))

    assert_response :success
  end

  test "signed in users can create a venue" do
    sign_in_as users(:member)

    assert_difference -> { Venue.count }, 1 do
      post venues_url, params: { venue: { club_id: clubs(:amsterdam).id, name: "Nieuw lokaal", address: "Straat 1",
        city: "Amsterdam", playing_day: 3, playing_time: "20:00" } }
    end
  end

  test "season-scoped venue forms keep the selected season in their action" do
    sign_in_as users(:member)
    slug = seasons(:previous).slug

    get new_venue_url(season_slug: slug)
    assert_select "form[action=?]", venues_path(season_slug: slug)

    get edit_venue_url(venues(:amsterdam), season_slug: slug)
    assert_select "form[action=?]", venue_path(venues(:amsterdam), season_slug: slug)
  end

  test "editing requires authentication" do
    get new_venue_url
    assert_redirected_to new_session_url
  end
end
