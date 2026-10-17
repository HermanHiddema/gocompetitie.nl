require "test_helper"

class GroupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @season = seasons(:current)
  end

  test "registering clubs requires authentication" do
    get groups_url(season_slug: @season.slug)
    assert_redirected_to new_session_url
  end

  test "only admins register the clubs of a season" do
    sign_in_as users(:member)

    get groups_url(season_slug: @season.slug)
    assert_response :unauthorized
  end

  test "index lists the clubs of the season with their linked clubs" do
    sign_in_as users(:admin)

    get groups_url(season_slug: @season.slug)

    assert_response :success
    assert_select "h1", "Clubs van Voorjaar 2026"
    assert_select "a[href=?]", edit_group_path(groups(:amsterdam)), text: "Go Club Amsterdam"
    assert_select "a[href=?]", club_path(clubs(:amsterdam), season_slug: @season.slug)
    assert_select "a", text: "Club aanmelden", count: 0
  end

  test "admins register clubs that field teams together or without a club" do
    sign_in_as users(:admin)
    @season.update!(phase: :draft)

    get new_group_url(season_slug: @season.slug)
    assert_select "form[action=?]", groups_path(season_slug: @season.slug)
    assert_select "input[type=checkbox][name='group[club_ids][]']", count: Club.count

    assert_difference -> { @season.groups.count }, 2 do
      post groups_url(season_slug: @season.slug), params: { group: { name: "Amsterdam/Utrecht",
        club_ids: ["", clubs(:amsterdam).id, clubs(:utrecht).id] } }
      assert_redirected_to groups_url(season_slug: @season.slug)

      post groups_url(season_slug: @season.slug), params: { group: { name: "TU Delft", club_ids: [""] } }
      assert_redirected_to groups_url(season_slug: @season.slug)
    end

    assert_equal [clubs(:amsterdam), clubs(:utrecht)].sort, @season.groups.find_by!(name: "Amsterdam/Utrecht").clubs.sort
    assert_empty @season.groups.find_by!(name: "TU Delft").clubs
  end

  test "a club is registered once per season" do
    sign_in_as users(:admin)
    @season.update!(phase: :draft)

    assert_no_difference -> { Group.count } do
      post groups_url(season_slug: @season.slug), params: { group: { name: "Go Club Amsterdam" } }
    end

    assert_response :unprocessable_content
  end

  test "clubs can no longer be registered once the season has started" do
    sign_in_as users(:admin)

    assert_no_difference -> { Group.count } do
      post groups_url(season_slug: @season.slug), params: { group: { name: "TU Delft" } }
    end

    assert_redirected_to season_url(@season)
  end

  test "admins change the clubs that a club is linked to" do
    sign_in_as users(:admin)
    group = groups(:amsterdam)

    get edit_group_url(group)
    assert_select "form[action=?]", group_path(group)

    patch group_url(group), params: { group: { name: "Amsterdam/Rotterdam", club_ids: ["", clubs(:amsterdam).id, clubs(:rotterdam).id] } }

    assert_redirected_to groups_url(season_slug: @season.slug)
    assert_equal "Amsterdam/Rotterdam", group.reload.name
    assert_equal [clubs(:amsterdam), clubs(:rotterdam)].sort, group.clubs.sort
  end

  test "clubs with teams cannot be deregistered" do
    sign_in_as users(:admin)
    @season.update!(phase: :draft)

    assert_no_difference -> { Group.count } do
      delete group_url(groups(:amsterdam))
    end
    assert_response :unprocessable_content

    group = @season.groups.create!(name: "TU Delft")
    assert_difference -> { Group.count }, -1 do
      delete group_url(group)
    end
    assert_redirected_to groups_url(season_slug: @season.slug)
  end

  test "clubs of a finished season can no longer be changed" do
    sign_in_as users(:admin)
    @season.update!(phase: :finished)

    patch group_url(groups(:amsterdam)), params: { group: { name: "Gewijzigd" } }

    assert_redirected_to season_url(@season)
    assert_equal "Go Club Amsterdam", groups(:amsterdam).reload.name
  end
end
