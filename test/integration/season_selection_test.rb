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

  test "an unknown season path returns not found" do
    get teams_url(season_slug: "does-not-exist")

    assert_response :not_found
  end

  test "the most recent season is shown without a season path" do
    get teams_url

    assert_response :success
    assert_select "footer", /Voorjaar 2026/
  end

  test "pages without a season path skip seasons with a blank slug" do
    Season.create!(name: "Zomer 2026").update_column(:slug, "")

    get teams_url

    assert_response :success
    assert_select "footer", /Voorjaar 2026/
  end

  test "clubs and venues keep the season of the path" do
    slug = seasons(:previous).slug

    [clubs_url(season_slug: slug), club_url(clubs(:amsterdam), season_slug: slug),
     venues_url(season_slug: slug), venue_url(venues(:amsterdam), season_slug: slug)].each do |url|
      get url

      assert_response :success
      assert_select "footer", /Najaar 2025/
      assert_select "a[href=?]", clubs_path(season_slug: slug)
      assert_select "a[href=?]", venues_path(season_slug: slug)
    end
  end

  test "a record of an older season selects that season" do
    league = seasons(:previous).leagues.create!(name: "Hoofdklasse", position: 0)
    team = league.teams.create!(name: "Amsterdam 9", abbrev: "Amst9", club: clubs(:amsterdam))
    participant = seasons(:previous).participants.create!(firstname: "Oude", lastname: "Speler")

    [league_url(league), team_url(team), participant_url(participant)].each do |url|
      get url

      assert_response :success
      assert_select "footer", /Najaar 2025/
      assert_select "a[href=?]", teams_path(season_slug: seasons(:previous).slug)
      assert_select "a[href=?]", season_path(seasons(:previous))
    end
  end
end
