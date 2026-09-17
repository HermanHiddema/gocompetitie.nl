require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  test "index lists the games of the season" do
    get games_url

    assert_response :success
    assert_select "h1", "Partijen"
    assert_select "[role='img'][aria-label='Zwart']"
    assert_select "[role='img'][aria-label='Wit']"
  end

  test "index puts the handicap in the black disc" do
    games(:board_one).update!(handicap: 2)

    get games_url

    assert_response :success
    assert_select "[role='img'][aria-label='Zwart, handicap 2']", text: "2", count: 1
    assert_select "[role='img'][aria-label='Wit']", text: "", minimum: 1
    assert_select "body", text: /H2/, count: 0
  end

  test "index renders the rated games as text" do
    get games_url(format: :text)

    assert_response :success
    assert_match "Speler1 Amsterdam Speler1 Utrecht +", response.body
  end
end
