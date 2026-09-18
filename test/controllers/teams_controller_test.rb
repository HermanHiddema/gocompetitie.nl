require "test_helper"

class TeamsControllerTest < ActionDispatch::IntegrationTest
  test "index lists the teams of the season" do
    get teams_url

    assert_response :success
    assert_select "a", text: "Amsterdam 1"
  end

  test "index lists the teams of the season alphabetically, across leagues" do
    teams(:amsterdam).update!(name: "Zwolle 1")
    leagues(:first).teams.create!(name: "Almere 1", abbrev: "Alme", club: clubs(:amsterdam))

    get teams_url

    assert_response :success
    names = css_select("a.font-semibold").map(&:text)
    assert_equal names.sort, names
    assert_equal "Almere 1", names.first
    assert_equal "Zwolle 1", names.last
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

  test "captains cannot edit teams" do
    sign_in_as users(:member)
    team = teams(:amsterdam)

    patch team_url(team), params: { team: { name: "Changed Team", abbrev: team.abbrev, club_id: team.club_id,
      league_id: team.league_id, captain_id: team.captain_id } }

    assert_response :unauthorized
    assert_equal "Amsterdam 1", team.reload.name
  end

  test "admins can create a team with members" do
    sign_in_as users(:admin)
    participant = seasons(:current).participants.create!(firstname: "Nieuwe", lastname: "Speler", rating: 1800, club: clubs(:amsterdam))

    assert_difference -> { Team.count }, 1 do
      post teams_url, params: { team: { name: "Amsterdam 2", abbrev: "Amst2", club_id: clubs(:amsterdam).id,
        league_id: leagues(:first).id, captain_id: people(:anna).id,
        team_members_attributes: { "0" => { board_number: 1, participant_id: participant.id } } } }
    end

    assert_equal 1, Team.last.team_members.count
  end

  test "teams can only be created inside the selected season" do
    sign_in_as users(:admin)
    league = seasons(:previous).leagues.create!(name: "Hoofdklasse", position: 0)

    assert_no_difference -> { Team.count } do
      post teams_url, params: { team: { name: "Amsterdam 9", abbrev: "Amst9", club_id: clubs(:amsterdam).id, league_id: league.id } }
    end

    assert_response :unprocessable_content
  end

  test "finished seasons can no longer change teams" do
    sign_in_as users(:admin)
    team = teams(:amsterdam)
    team.season.update!(phase: :finished)

    patch team_url(team), params: { team: { name: "Gewijzigd", abbrev: team.abbrev, club_id: team.club_id,
      league_id: team.league_id, captain_id: team.captain_id } }

    assert_redirected_to season_url(team.season)
    assert_equal "Amsterdam 1", team.reload.name

    assert_no_difference -> { Team.count } do
      delete team_url(team)
    end

    assert_redirected_to season_url(team.season)
  end

  test "teams can only move to leagues in their own season" do
    sign_in_as users(:admin)
    team = leagues(:first).teams.create!(name: "Amsterdam 9", abbrev: "Amst9", club: clubs(:amsterdam))
    league = seasons(:previous).leagues.create!(name: "Eerste klasse", position: 1)

    patch team_url(team), params: { team: { name: "Gewijzigd", abbrev: team.abbrev, club_id: team.club_id,
      league_id: league.id, captain_id: team.captain_id } }

    assert_response :unprocessable_content
    assert_equal leagues(:first), team.reload.league
  end

  test "team edits without league_id keep the existing league" do
    sign_in_as users(:admin)
    team = teams(:amsterdam)
    league = team.league

    patch team_url(team), params: { team: { name: "Gewijzigd", abbrev: team.abbrev, club_id: team.club_id,
      captain_id: team.captain_id } }

    assert_redirected_to team_url(team)
    assert_equal "Gewijzigd", team.reload.name
    assert_equal league, team.league
  end

  test "historical season team links and forms keep the selected season" do
    sign_in_as users(:admin)
    previous = seasons(:previous)
    seasons(:current).update!(phase: :draft)
    previous.update!(phase: :active)
    league = previous.leagues.create!(name: "Hoofdklasse", position: 0)

    get teams_url(season_slug: previous.slug)
    assert_select "a[href=?]", new_team_path(season_slug: previous.slug)

    get new_team_url(season_slug: previous.slug, league_id: league.id)
    assert_select "form[action=?]", teams_path(season_slug: previous.slug)
    assert_select "option", text: "Hoofdklasse"
    assert_select "footer", /Najaar 2025/
  end

  test "a team without a name is rendered again" do
    sign_in_as users(:admin)

    post teams_url, params: { team: { name: "", abbrev: "", club_id: clubs(:amsterdam).id, league_id: leagues(:first).id } }

    assert_response :unprocessable_content
  end
end
