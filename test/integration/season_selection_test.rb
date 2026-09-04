require "test_helper"

class SeasonSelectionTest < ActionDispatch::IntegrationTest
  test "the most recent season is shown by default" do
    get root_url

    assert_select "h1", "Stand #{Season.recent.first.name}"
  end

  test "a season subdomain selects that season" do
    host! "najaar-2025.gocompetitie.nl"
    get root_url

    assert_select "h1", "Stand Najaar 2025"
  end
end
