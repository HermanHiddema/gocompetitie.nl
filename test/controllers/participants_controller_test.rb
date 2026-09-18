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
    sign_in_as users(:admin)

    assert_difference -> { seasons(:current).participants.count }, 1 do
      post participants_url, params: { participant: { firstname: "Nieuwe", lastname: "Speler", rating: 1600, rank: "5k",
        club_id: clubs(:amsterdam).id } }
    end

    participant = Participant.last
    assert_equal "5k", participant.rank
    assert_equal seasons(:current), participant.season
  end

  test "historical season participant links and forms keep the selected season" do
    sign_in_as users(:admin)
    previous = seasons(:previous)
    seasons(:current).update!(phase: :draft)
    previous.update!(phase: :active)

    get participants_url(season_slug: previous.slug)
    assert_select "a[href=?]", new_participant_path(season_slug: previous.slug)

    get new_participant_url(season_slug: previous.slug)
    assert_select "form[action=?]", participants_path(season_slug: previous.slug)
    assert_select "footer", /Najaar 2025/

    assert_difference -> { previous.participants.count }, 1 do
      post participants_url(season_slug: previous.slug), params: { participant: { firstname: "Nieuwe", lastname: "Speler",
        rating: 1600, rank: "5k", club_id: clubs(:amsterdam).id } }
    end

    assert_equal previous, Participant.last.season
  end

  test "adding a participant requires a season" do
    Season.destroy_all
    sign_in_as users(:admin)

    get new_participant_url

    assert_redirected_to seasons_url
  end

  test "editing requires authentication" do
    get edit_participant_url(participants(:amsterdam_1))
    assert_redirected_to new_session_url
  end

  test "finished seasons can no longer change participants" do
    sign_in_as users(:admin)
    participant = participants(:amsterdam_1)
    participant.season.update!(phase: :finished)

    patch participant_url(participant), params: { participant: { firstname: "Gewijzigd", lastname: participant.lastname,
      rating: participant.rating, egd_pin: participant.egd_pin, club_id: participant.club_id, rank: participant.rank } }

    assert_redirected_to season_url(participant.season)
    assert_equal "Speler1", participant.reload.firstname

    assert_no_difference -> { Participant.count } do
      delete participant_url(participant)
    end

    assert_redirected_to season_url(participant.season)
  end
end
