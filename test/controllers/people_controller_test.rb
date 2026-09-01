require "test_helper"

class PeopleControllerTest < ActionDispatch::IntegrationTest
  test "index lists people" do
    get people_url

    assert_response :success
    assert_select "a", text: "Anna Amsterdam"
  end

  test "contact details are hidden for visitors" do
    get person_url(people(:anna))

    assert_no_match "anna@example.com", response.body
  end

  test "contact details are visible when signed in" do
    sign_in_as users(:member)

    get person_url(people(:anna))

    assert_match "anna@example.com", response.body
  end

  test "signed in users can create a person" do
    sign_in_as users(:member)

    assert_difference -> { Person.count }, 1 do
      post people_url, params: { person: { firstname: "Nieuw", lastname: "Persoon", email: "nieuw@example.com" } }
    end
  end
end
