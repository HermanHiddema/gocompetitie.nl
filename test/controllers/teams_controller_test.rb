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
    participant = seasons(:current).participants.create!(firstname: "Nieuwe", lastname: "Speler", rating: 1800, club: clubs(:amsterdam))

    assert_difference -> { Team.count }, 1 do
      post teams_url, params: { team: { name: "Amsterdam 2", abbrev: "Amst2", club_id: clubs(:amsterdam).id,
        league_id: leagues(:first).id, captain_id: people(:anna).id,
        team_members_attributes: { "0" => { board_number: 1, participant_id: participant.id } } } }
    end

    assert_equal 1, Team.last.team_members.count
  end

  test "historical season team links and forms keep the selected season" do
    sign_in_as users(:member)
    previous = seasons(:previous)
    league = previous.leagues.create!(name: "Hoofdklasse", position: 0)

    get teams_url(season_slug: previous.slug)
    assert_select "a[href=?]", new_team_path(season_slug: previous.slug)

    get new_team_url(season_slug: previous.slug, league_id: league.id)
    assert_select "form[action=?]", teams_path(season_slug: previous.slug)
    assert_select "option", text: "Hoofdklasse"
    assert_select "footer", /Najaar 2025/
  end

  test "a team without a name is rendered again" do
    sign_in_as users(:member)

    post teams_url, params: { team: { name: "", abbrev: "", club_id: clubs(:amsterdam).id, league_id: leagues(:first).id } }

    assert_response :unprocessable_content
  end
end
