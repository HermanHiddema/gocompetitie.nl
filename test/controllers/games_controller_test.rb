require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  test "index lists the games of the season" do
    get games_url

    assert_response :success
    assert_select "h1", "Partijen"
  end

  test "index renders the rated games as text" do
    get games_url(format: :text)

    assert_response :success
    assert_match "Speler1 Amsterdam Speler1 Utrecht +", response.body
  end
end
