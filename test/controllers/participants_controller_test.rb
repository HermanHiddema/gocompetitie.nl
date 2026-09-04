require "test_helper"

class ParticipantsControllerTest < ActionDispatch::IntegrationTest
  test "index lists the participants of the season" do
    get participants_url

    assert_response :success
    assert_select "a", text: "Speler1 Amsterdam"
  end

  test "show lists the games of a participant" do
    get participant_url(participants(:amsterdam_1))

    assert_response :success
  end

  test "signed in users can add a participant to the current season" do
    sign_in_as users(:member)

    assert_difference -> { seasons(:current).participants.count }, 1 do
      post participants_url, params: { participant: { firstname: "Nieuwe", lastname: "Speler", rating: 1600, rank: "5k",
        club_id: clubs(:amsterdam).id } }
    end

    participant = Participant.last
    assert_equal "5k", participant.rank
    assert_equal seasons(:current), participant.season
  end

  test "adding a participant requires a season" do
    Season.destroy_all
    sign_in_as users(:member)

    get new_participant_url

    assert_redirected_to seasons_url
  end

  test "editing requires authentication" do
    get edit_participant_url(participants(:amsterdam_1))
    assert_redirected_to new_session_url
  end
end
