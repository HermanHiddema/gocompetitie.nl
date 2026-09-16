require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "new users are captains" do
    user = User.new(email_address: "new@teams.gocompetitie.nl", password: "password")

    assert user.captain?
    assert_not user.admin?
  end

  test "role is limited to the known roles" do
    user = users(:captain)
    user.role = "wizard"

    assert_not user.valid?
    assert_predicate user.errors[:role], :any?
  end
end
