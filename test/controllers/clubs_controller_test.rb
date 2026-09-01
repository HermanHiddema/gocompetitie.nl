require "test_helper"

class ClubsControllerTest < ActionDispatch::IntegrationTest
  test "index is public" do
    get clubs_url
    assert_response :success
    assert_select "h1", "Clubs"
  end

  test "index only lists clubs with a proper name unless all is given" do
    Club.create!(name: "Xyz", abbrev: "Xyz")

    get clubs_url
    assert_select "a", text: "Xyz", count: 0

    get clubs_url(all: 1)
    assert_select "a", text: "Xyz", count: 1
  end

  test "show renders club details" do
    get club_url(clubs(:amsterdam))
    assert_response :success
    assert_select "h1", /Go Club Amsterdam/
  end

  test "editing requires authentication" do
    get new_club_url
    assert_redirected_to new_session_url
  end

  test "signed in users can create a club" do
    sign_in_as users(:member)

    assert_difference -> { Club.count }, 1 do
      post clubs_url, params: { club: { name: "Go Club Delft", abbrev: "Delf" } }
    end

    assert_redirected_to club_url(Club.last)
  end

  test "invalid clubs are rendered again" do
    sign_in_as users(:member)

    assert_no_difference -> { Club.count } do
      post clubs_url, params: { club: { name: "" } }
    end

    assert_response :unprocessable_content
  end

  test "signed in users can update and destroy a club" do
    sign_in_as users(:member)
    club = clubs(:rotterdam)

    patch club_url(club), params: { club: { name: "Go Club Rotterdam Zuid" } }
    assert_redirected_to club_url(club)
    assert_equal "Go Club Rotterdam Zuid", club.reload.name

    club.teams.destroy_all
    club.venues.destroy_all
    delete club_url(club)
    assert_redirected_to clubs_url
  end
end
