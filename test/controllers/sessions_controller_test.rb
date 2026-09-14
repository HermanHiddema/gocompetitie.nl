require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
    assert_select "meta[name=?][content=?]", "turbo-cache-control", "no-cache"
    assert_select "form[action=?][data-turbo=?]", session_path, "false"
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]

    get edit_league_path(leagues(:top))

    assert_response :success
    assert_select "details summary", /#{Regexp.escape(@user.email_address)}/
    assert_select "details form[action=?] button", session_path, "Uitloggen"
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
