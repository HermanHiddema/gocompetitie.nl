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
    assert_dom_equal %(<span role="img" aria-label="concept" title="concept">📄</span>), season_phase_badge(season)

    season.phase = :active
    assert_dom_equal %(<span role="img" aria-label="lopend" title="lopend">➡️</span>), season_phase_badge(season)

    season.phase = :finished
    assert_dom_equal %(<span role="img" aria-label="afgesloten" title="afgesloten">✅</span>), season_phase_badge(season)
  end
end
