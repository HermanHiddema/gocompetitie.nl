require "test_helper"

class TeamsControllerTest < ActionDispatch::IntegrationTest
  test "index lists the teams of the season" do
    get teams_url

    assert_response :success
    assert_select "a", text: "Amsterdam 1"
  end

  test "show lists members and matches" do
    get team_url(teams(:amsterdam))

    assert_response :success
    assert_select "h1", "Team Amsterdam 1"
  end

  test "new requires authentication" do
    get new_team_url
    assert_redirected_to new_session_url
  end

  test "signed in users can create a team with members" do
    sign_in_as users(:member)

    assert_difference -> { Team.count }, 1 do
      post teams_url, params: { team: { name: "Amsterdam 2", abbrev: "Amst2", club_id: clubs(:amsterdam).id,
        league_id: leagues(:first).id, captain_id: people(:anna).id,
        team_members_attributes: { "0" => { board_number: 1, participant_id: participants(:amsterdam_1).id } } } }
    end

    assert_equal 1, Team.last.team_members.count
  end

  test "a team without a name is rendered again" do
    sign_in_as users(:member)

    post teams_url, params: { team: { name: "", abbrev: "", club_id: clubs(:amsterdam).id, league_id: leagues(:first).id } }

    assert_response :unprocessable_content
  end
end
