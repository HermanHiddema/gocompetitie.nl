require "test_helper"

class ParticipantsControllerTest < ActionDispatch::IntegrationTest
  class FakeEgdClient
    attr_reader :searches

    def initialize(players)
      @players = players
      @searches = []
    end

    def search_players(search, limit:)
      @searches << { search: search, limit: limit }
      @players
    end
  end

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

  test "signed in users can search EGD players while adding a participant to an editable season" do
    sign_in_as users(:admin)
    client = FakeEgdClient.new([
      { "pin" => 12345678, "firstName" => "Jan", "lastName" => "Jansen", "club" => "Tstv", "grade" => "2k",
        "rating" => 1850 }
    ])

    with_egd_client(client) do
      get new_participant_url(season_slug: seasons(:current).slug, egd_search: "Jan")
    end

    assert_response :success
    assert_equal [{ search: "Jan", limit: 20 }], client.searches
    assert_select "turbo-frame#egd_search"
    assert_select "h2", text: "Zoeken in de EGD"
    assert_select "form[action=?][data-controller=?][data-turbo-frame=?]", new_participant_path(season_slug: seasons(:current).slug),
      "autosubmit", "egd_search"
    assert_select "input[name=?][data-action=?]", "egd_search", "input->autosubmit#queue search->autosubmit#queue"
    assert_select "div", text: /Jan Jansen/
    assert_select "form[action=?]", import_egd_participants_path(season_slug: seasons(:current).slug)
  end

  test "EGD search shows at most 20 players" do
    sign_in_as users(:admin)
    client = FakeEgdClient.new(25.times.map do |index|
      { "pin" => index, "firstName" => "Speler", "lastName" => index.to_s, "club" => "Tstv", "grade" => "2k", "rating" => 1850 - index }
    end)

    with_egd_client(client) do
      get new_participant_url(season_slug: seasons(:current).slug, egd_search: "Speler")
    end

    assert_response :success
    assert_equal 20, css_select("input[value='Toevoegen uit EGD']").size
  end

  test "signed in users can import one EGD player into an active season" do
    sign_in_as users(:admin)

    assert_difference -> { seasons(:current).participants.count }, 1 do
      post import_egd_participants_url(season_slug: seasons(:current).slug),
        params: { egd_player: { pin: 12345678, firstName: "Jan", lastName: "Jansen", club: "Tstv", grade: "2k", rating: 1850 } }
    end

    participant = Participant.last
    assert_redirected_to participant_url(participant)
    assert_equal seasons(:current), participant.season
    assert_equal "12345678", participant.egd_pin
    assert_equal "2k", participant.rank
    assert_equal "Tstv", participant.club.abbrev
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

    client = FakeEgdClient.new([
      { "pin" => 12345678, "firstName" => "Jan", "lastName" => "Jansen", "club" => "Tstv", "grade" => "2k",
        "rating" => 1850 }
    ])
    with_egd_client(client) do
      get new_participant_url(season_slug: previous.slug, egd_search: "Jan")
    end
    assert_select "form[action=?]", import_egd_participants_path(season_slug: previous.slug)

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

    get new_participant_url(season_slug: participant.season.slug)

    assert_redirected_to season_url(participant.season)

    patch participant_url(participant), params: { participant: { firstname: "Gewijzigd", lastname: participant.lastname,
      rating: participant.rating, egd_pin: participant.egd_pin, club_id: participant.club_id, rank: participant.rank } }

    assert_redirected_to season_url(participant.season)
    assert_equal "Speler1", participant.reload.firstname

    assert_no_difference -> { participant.season.participants.count } do
      post import_egd_participants_url(season_slug: participant.season.slug),
        params: { egd_player: { pin: 12345678, firstName: "Jan", lastName: "Jansen", club: "Tstv", grade: "2k", rating: 1850 } }
    end

    assert_redirected_to season_url(participant.season)

    assert_no_difference -> { Participant.count } do
      delete participant_url(participant)
    end

    assert_redirected_to season_url(participant.season)
  end

  private
    def with_egd_client(client)
      singleton_class = Egd::Client.singleton_class
      original_new = Egd::Client.method(:new)
      singleton_class.send(:define_method, :new, ->(*, **) { client })
      yield
    ensure
      singleton_class.send(:define_method, :new, original_new)
    end
end
