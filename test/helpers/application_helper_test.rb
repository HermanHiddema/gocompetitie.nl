require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "formats supported fractions without decimals" do
    assert_equal "2", format_fraction(2)
    assert_equal "½", format_fraction(0.5)
    assert_equal "1½", format_fraction(1.5)
    assert_equal "¼", format_fraction(0.25)
    assert_equal "⅜", format_fraction(0.375)
    assert_equal "-½", format_fraction(-0.5)
  end

  test "formats points scored against another team" do
    assert_equal "½", format_fraction(0.5)
  end

  test "uses decimals for unsupported fractions" do
    assert_equal "0.17", format_fraction(0.17)
  end

  test "formats match results with fractions" do
    match = matches(:amsterdam_utrecht)
    games(:board_three).update!(home_points: 1, away_points: 1)

    assert_equal "1½-1½", format_match_result(match.reload)
  end

  test "shows the phase of a season as an icon" do
    season = seasons(:current)

    season.phase = :draft
    assert_dom_equal %(<span role="img" aria-label="concept" title="concept">⏸️</span>), season_phase_badge(season)

    season.phase = :active
    assert_dom_equal %(<span role="img" aria-label="lopend" title="lopend">➡️</span>), season_phase_badge(season)

    season.phase = :finished
    assert_dom_equal %(<span role="img" aria-label="afgesloten" title="afgesloten">✅</span>), season_phase_badge(season)

    season.phase = :cancelled
    assert_dom_equal %(<span role="img" aria-label="geannuleerd" title="geannuleerd">🛑</span>), season_phase_badge(season)
  end

  test "puts the buttons of a page next to its title" do
    render inline: <<~ERB
      <%= page_header("Teams") do %><%= button_link_to("Team toevoegen", "/teams/new", short: "+ Team") %><% end %>
    ERB

    assert_select "div > div > h1", text: "Teams"
    assert_select "div > div > a[href=?]", "/teams/new"
  end

  test "omits the buttons of a page without them" do
    header = page_header("Teams") { "" }

    assert_dom_equal %(<div class="flex flex-wrap items-center justify-between gap-x-4 gap-y-2 mb-6">) +
      %(<div class="flex flex-wrap items-center gap-3"><h1 class="text-2xl font-bold">Teams</h1></div></div>), header
  end

  test "shows a shorter button label on small screens" do
    assert_dom_equal %(<span class="sm:hidden">+ Team</span><span class="hidden sm:inline">Team toevoegen</span>),
      button_label("Team toevoegen", "+ Team")
  end

  test "shows a single button label without a shorter one" do
    assert_equal "Team toevoegen", button_label("Team toevoegen")
  end
end
