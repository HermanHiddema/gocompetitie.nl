require "test_helper"

class SeasonsControllerTest < ActionDispatch::IntegrationTest
  test "index lists all seasons" do
    get seasons_url

    assert_response :success
    assert_select "a", text: "Voorjaar 2026"
  end

  test "index shows the statistics of each season" do
    get seasons_url

    assert_response :success
    assert_select "section div", text: "2 poules", count: 1
    assert_select "section div", text: "3 clubs", count: 1
    assert_select "section div", text: "3 teams", count: 1
    assert_select "section div", text: "7 deelnemers", count: 1
  end

  test "index pluralizes singular season statistics" do
    season = Season.create!(name: "Najaar 2026", phase: :finished)
    league = season.leagues.create!(name: "Hoofdklasse", position: 0)
    league.teams.create!(name: "Amsterdam 1", abbrev: "Amst1", club: clubs(:amsterdam))

    get seasons_url

    assert_response :success
    assert_select "section div", text: "1 poule", count: 1
    assert_select "section div", text: "1 club", count: 1
    assert_select "section div", text: "1 team", count: 1
  end

  test "index does not show season edit links" do
    get seasons_url
    assert_select "a[href=?]", edit_season_path(seasons(:current)), count: 0

    sign_in_as users(:admin)
    get seasons_url

    assert_select "a[href=?]", edit_season_path(seasons(:current)), count: 0
    assert_select "a[href=?]", edit_season_path(seasons(:previous)), count: 0
  end

  test "show only offers admins an edit link for editable seasons" do
    get season_url(seasons(:current))
    assert_select "a[href=?]", edit_season_path(seasons(:current)), count: 0

    sign_in_as users(:admin)
    get season_url(seasons(:current))

    assert_select "a[href=?]", edit_season_path(seasons(:current)), count: 1

    get season_url(seasons(:previous))
    assert_select "a[href=?]", edit_season_path(seasons(:previous)), count: 0
  end

  test "show renders the standings of the season" do
    get season_url(seasons(:current))

    assert_response :success
    assert_select "h1", "Stand Voorjaar 2026"
    assert_select "table"
    assert_select "div.grid > section.min-w-0", count: seasons(:current).leagues.count
  end

  test "the front page redirects to the active season" do
    get root_url

    assert_redirected_to season_url(seasons(:current))
  end

  test "the front page redirects to the last finished season without an active one" do
    seasons(:current).update!(phase: :draft)

    get root_url

    assert_redirected_to season_url(seasons(:previous))
  end

  test "draft seasons are only accessible to admins" do
    draft = Season.create!(name: "Najaar 2026")

    get season_url(draft)
    assert_response :not_found

    get seasons_url
    assert_select "a", text: draft.name, count: 0

    sign_in_as users(:admin)
    get season_url(draft)
    assert_response :success
  end

  test "admins start and finish a season" do
    sign_in_as users(:admin)
    draft = Season.create!(name: "Najaar 2026")
    seasons(:current).update!(phase: :finished)

    post start_season_url(draft)

    assert_redirected_to season_url(draft)
    assert draft.reload.active?
  end

  test "starting a season is refused when another season is active" do
    sign_in_as users(:admin)
    draft = Season.create!(name: "Najaar 2026")

    post start_season_url(draft)

    assert_redirected_to season_url(draft)
    assert draft.reload.draft?
    assert_equal "Fase is al in gebruik door een ander seizoen", flash[:alert]
  end

  test "finishing a season sets the unplayed games to 0-0" do
    sign_in_as users(:admin)
    season = seasons(:current)

    post finish_season_url(season)

    assert_redirected_to season_url(season)
    assert season.reload.finished?
    assert_equal "0-0", games(:unplayed).reload.result
  end

  test "finished seasons cannot be started again" do
    sign_in_as users(:admin)
    season = seasons(:current)

    post finish_season_url(season)
    post start_season_url(season)

    assert_redirected_to season_url(season)
    assert season.reload.finished?
    assert_equal "Alleen een seizoen in de fase draft kan worden gestart.", flash[:alert]
  end

  test "draft seasons cannot be finished" do
    sign_in_as users(:admin)
    draft = Season.create!(name: "Najaar 2026")

    post finish_season_url(draft)

    assert_redirected_to season_url(draft)
    assert draft.reload.draft?
    assert_equal "Alleen een seizoen in de fase active kan worden afgesloten.", flash[:alert]
  end

  test "only admins can finish a season" do
    sign_in_as users(:member)

    post finish_season_url(seasons(:current))

    assert_response :unauthorized
    assert seasons(:current).reload.active?
  end

  test "the season page warns about unplayed games before finishing" do
    sign_in_as users(:admin)

    get season_url(seasons(:current))

    assert_response :success
    assert_select "form[action=?][data-turbo-confirm*=?]", finish_season_path(seasons(:current)), "1 ongespeelde partij"
  end

  test "finished seasons no longer show schedule links in the standings" do
    sign_in_as users(:admin)
    seasons(:current).update!(phase: :finished)

    get season_url(seasons(:current))

    assert_response :success
    assert_select "a", text: "+", count: 0
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

    assert_redirected_to season_url(Season.find_by(slug: "najaar-2026"))
  end

  test "admins can open the form for a new season" do
    sign_in_as users(:admin)

    get new_season_url

    assert_response :success
    assert_select "form"
    assert_select "select[name='season[handicap_adjustment]'] option[selected][value='3']"
  end

  test "admins can disable handicaps for a season" do
    sign_in_as users(:admin)
    season = seasons(:current)

    patch season_url(season), params: { season: { name: season.name, handicap_adjustment: "" } }

    assert_redirected_to season_url(season)
    assert_nil season.reload.handicap_adjustment
  end

  test "creating a season without a name renders the form again" do
    sign_in_as users(:admin)

    assert_no_difference -> { Season.count } do
      post seasons_url, params: { season: { name: "" } }
    end

    assert_response :unprocessable_content
    assert_select "form"
  end
end
