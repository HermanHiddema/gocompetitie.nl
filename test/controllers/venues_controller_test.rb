require "test_helper"

class VenuesControllerTest < ActionDispatch::IntegrationTest
  test "index lists the venues" do
    get venues_url

    assert_response :success
    assert_select "a", text: "Amsterdam"
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

  test "editing requires authentication" do
    get new_venue_url
    assert_redirected_to new_session_url
  end
end
