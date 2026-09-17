require "test_helper"

class MatchesControllerTest < ActionDispatch::IntegrationTest
  setup { @match = matches(:amsterdam_utrecht) }

  test "index lists the matches of the season grouped by date" do
    get matches_url

    assert_response :success
    assert_select "h1", "Wedstrijden"
  end

  test "show renders the games of a match" do
    get match_url(@match)

    assert_response :success
    assert_select "h1", /Amsterdam 1/
  end

  test "new requires authentication" do
    get new_match_url
    assert_redirected_to new_session_url
  end

  test "admins can schedule a match, which fills the boards" do
    sign_in_as users(:admin)

    assert_difference -> { Match.count }, 1 do
      post matches_url, params: { match: { league_id: leagues(:top).id, home_team_id: teams(:amsterdam).id,
        away_team_id: teams(:rotterdam).id, venue_id: venues(:amsterdam).id,
        playing_date: "2026-04-01", playing_time: "20:00" } }
    end

    match = Match.last
    assert_redirected_to edit_match_url(match)
    assert_equal 3, match.games.count
  end

  test "historical season match links and forms keep the selected season" do
    sign_in_as users(:admin)
    previous = seasons(:previous)
    league = previous.leagues.create!(name: "Hoofdklasse", position: 0)
    home_team = league.teams.create!(name: "Amsterdam 9", abbrev: "Amst9", club: clubs(:amsterdam))
    away_team = league.teams.create!(name: "Utrecht 9", abbrev: "Utre9", club: clubs(:utrecht))

    get matches_url(season_slug: previous.slug)
    assert_select "a[href=?]", new_match_path(season_slug: previous.slug)

    get new_match_url(season_slug: previous.slug, league_id: league.id, home_team_id: home_team.id, away_team_id: away_team.id)
    assert_select "form[action=?]", matches_path(season_slug: previous.slug)
    assert_select "option", text: "Amsterdam 9"
    assert_select "footer", /Najaar 2025/
  end

  test "edit lists selectable players without creating boards" do
    sign_in_as users(:member)
    @match.games.destroy_all

    assert_no_difference -> { @match.games.count } do
      get edit_match_url(@match)
    end

    assert_response :success
  end

  test "edit can list all participants of the season" do
    sign_in_as users(:admin)

    get edit_match_url(@match, all: 1)

    assert_response :success
    assert_select "option", text: /Rotterdam/
  end

  test "edit puts labeled handicap controls before results" do
    sign_in_as users(:member)

    get edit_match_url(@match)

    assert_response :success
    assert_select "label:not(.sr-only)", text: "Handicap", count: Match::BOARD_COUNT
    assert_select "label.sr-only", text: "Resultaat", count: Match::BOARD_COUNT

    field_names = css_select("select").filter_map { |select| select["name"] if select["name"]&.include?("games_attributes") }
    assert_operator field_names.index { |name| name.end_with?("[handicap]") }, :<,
      field_names.index { |name| name.end_with?("[result]") }
  end

  test "edit keeps automatic handicap previews in sync with player choices" do
    sign_in_as users(:member)

    get edit_match_url(@match)

    assert_response :success
    assert_select "[data-controller='handicap'][data-handicap-adjustment-value='3']", count: Match::BOARD_COUNT
    assert_select "select[data-handicap-target='home'][data-action='change->handicap#update']", count: Match::BOARD_COUNT
    assert_select "select[data-handicap-target='away'][data-action='change->handicap#update']", count: Match::BOARD_COUNT
    assert_select "select[data-handicap-target='handicap'] option[value='']", text: "auto (0)", count: Match::BOARD_COUNT
    assert_select "select[data-handicap-target='handicap'] option[disabled]", count: Match::BOARD_COUNT * Game::HANDICAPS.max
  end

  test "edit omits handicap controls when the season disables handicaps" do
    sign_in_as users(:member)
    @match.season.update!(handicap_adjustment: nil)

    get edit_match_url(@match)

    assert_response :success
    assert_select "[data-controller='handicap']", count: 0
    assert_select "label", text: "Handicap", count: 0
    assert_select "select[name$='[handicap]']", count: 0
    assert_select "select[name$='[result]']", count: Match::BOARD_COUNT
  end

  test "edit keeps an over-limit selected handicap enabled until javascript recalculates it" do
    sign_in_as users(:member)
    game = @match.games.find_by(board_number: 1)
    game.away_player.update!(rating: 1500)
    game.update!(handicap: 3)
    game.away_player.update!(rating: 2000)

    get edit_match_url(@match)

    assert_response :success
    assert_select "select[data-handicap-target='handicap'] option[selected][value='3']:not([disabled])", count: 1
  end

  test "captains can enter results" do
    sign_in_as users(:member)
    game = @match.games.find_by(board_number: 1)

    patch match_url(@match), params: { match: { playing_time: "19:00", games_attributes: {
      "0" => { id: game.id, home_id: game.home_id, away_id: game.away_id, result: "0-1!" } } } }

    assert_redirected_to match_url(@match)
    assert_equal "0-1!", game.reload.result
    assert game.forfeit?
    assert_equal "19:00", @match.reload.playing_time
  end

  test "captains can enter the handicap that was used" do
    sign_in_as users(:member)
    game = @match.games.find_by(board_number: 1)
    game.away_player.update!(rating: 1500)

    patch match_url(@match), params: { match: { games_attributes: {
      "0" => { id: game.id, home_id: game.home_id, away_id: game.away_id, result: "1-0", handicap: "3" } } } }

    assert_redirected_to match_url(@match)
    assert_equal 3, game.reload.handicap
  end

  test "captains can keep or clear the automatic handicap" do
    sign_in_as users(:member)
    game = @match.games.find_by(board_number: 1)
    game.away_player.update!(rating: 1500)

    patch match_url(@match), params: { match: { games_attributes: {
      "0" => { id: game.id, home_id: game.home_id, away_id: game.away_id, result: "1-0", handicap: "" } } } }

    assert_redirected_to match_url(@match)
    assert_nil game.reload.entered_handicap

    game.update!(handicap: 3)

    patch match_url(@match), params: { match: { games_attributes: {
      "0" => { id: game.id, home_id: game.home_id, away_id: game.away_id, result: "1-0", handicap: "" } } } }

    assert_redirected_to match_url(@match)
    assert_nil game.reload.entered_handicap
  end

  test "captains can update games with an existing handicap after handicaps are disabled" do
    sign_in_as users(:member)
    game = @match.games.find_by(board_number: 1)
    game.away_player.update!(rating: 1500)
    game.update!(handicap: 1)
    @match.season.update!(handicap_adjustment: nil)

    patch match_url(@match), params: { match: { games_attributes: {
      "0" => { id: game.id, home_id: game.home_id, away_id: game.away_id, result: "0-1" } } } }

    assert_redirected_to match_url(@match)
    assert_equal "0-1", game.reload.result
    assert_equal 1, game.reload[:handicap]
  end

  test "captains cannot enter a handicap above the automatic value" do
    sign_in_as users(:member)
    game = @match.games.find_by(board_number: 1)

    patch match_url(@match), params: { match: { games_attributes: {
      "0" => { id: game.id, home_id: game.home_id, away_id: game.away_id, result: "1-0", handicap: "1" } } } }

    assert_response :unprocessable_content
    assert_nil game.reload.entered_handicap
  end

  test "captains can swap players between boards" do
    sign_in_as users(:member)
    first, second = @match.games.by_board.first(2)

    patch match_url(@match), params: { match: { games_attributes: {
      "0" => { id: first.id, home_id: second.home_id, away_id: second.away_id },
      "1" => { id: second.id, home_id: first.home_id, away_id: first.away_id } } } }

    assert_redirected_to match_url(@match)
    assert_equal participants(:amsterdam_2).id, first.reload.home_id
    assert_equal participants(:amsterdam_1).id, second.reload.home_id
  end

  test "admins can delete a match" do
    sign_in_as users(:admin)

    assert_difference -> { Match.count }, -1 do
      delete match_url(@match)
    end

    assert_redirected_to matches_url(season_slug: @match.season.slug)
  end

  test "captains cannot schedule or delete matches" do
    sign_in_as users(:member)

    get match_url(@match)
    assert_select "a[href=?]", edit_match_path(@match)
    assert_select "form[action=?]", match_path(@match), count: 0

    assert_no_difference -> { Match.count } do
      post matches_url, params: { match: { league_id: leagues(:top).id, home_team_id: teams(:amsterdam).id,
        away_team_id: teams(:rotterdam).id, venue_id: venues(:amsterdam).id,
        playing_date: "2026-04-01", playing_time: "20:00" } }
    end

    assert_response :unauthorized

    assert_no_difference -> { Match.count } do
      delete match_url(@match)
    end

    assert_response :unauthorized
  end
end
