require "test_helper"

# == Schema Information
#
# Table name: people
#
#  id         :bigint           not null, primary key
#  egd_pin    :string
#  email      :string
#  email2     :string
#  firstname  :string           not null
#  lastname   :string           not null
#  phone      :string
#  phone2     :string
#  rating     :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  club_id    :bigint
#
# Indexes
#
#  index_people_on_club_id  (club_id)
#  index_people_on_egd_pin  (egd_pin) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (club_id => clubs.id)
#
class PersonTest < ActiveSupport::TestCase
  test "an EGD pin may only be used by one person" do
    people(:anna).update!(egd_pin: "12345678")
    duplicate = Person.new(firstname: "Anna", lastname: "Amsterdam", egd_pin: "12345678")

    assert_not duplicate.valid?
    assert_equal [:egd_pin], duplicate.errors.attribute_names
  end

  test "a blank EGD pin is stored as nil and may be shared" do
    person = Person.create!(firstname: "Dirk", lastname: "Delft", egd_pin: "")

    assert_nil person.egd_pin
    assert_predicate Person.new(firstname: "Eva", lastname: "Eindhoven", egd_pin: ""), :valid?
  end

  test "merging a person reattaches its relations and deletes it" do
    anna = people(:anna)
    bram = people(:bram)
    participant = participants(:amsterdam_1)
    participant.update!(person: anna)

    anna.merge_into!(bram)

    assert_not Person.exists?(anna.id)
    assert_equal bram, participant.reload.person
    assert_equal bram, teams(:amsterdam).reload.captain
    assert_equal bram, clubs(:amsterdam).reload.contact_person
  end

  test "a person cannot be merged into itself" do
    assert_raises(ArgumentError) { people(:anna).merge_into!(people(:anna)) }
  end

  test "duplicate EGD pins are merged into the person updated most recently" do
    anna = people(:anna)
    bram = people(:bram)
    carla = people(:carla)

    without_unique_egd_pin_index do
      anna.update_columns(egd_pin: "12345678", updated_at: 2.days.ago)
      bram.update_columns(egd_pin: "12345678", updated_at: 1.day.ago)
      carla.update_columns(egd_pin: "87654321", updated_at: 1.day.ago)

      assert_equal 1, Person.merge_egd_pin_duplicates!
    end

    assert_not Person.exists?(anna.id)
    assert_equal bram, clubs(:amsterdam).reload.contact_person
    assert_equal [bram, carla].sort_by(&:id), Person.where.not(egd_pin: nil).order(:id).to_a
  end

  private
    # Duplicate pins only exist in databases from before the unique index, so it
    # is dropped inside the transaction of the test to be able to create them.
    def without_unique_egd_pin_index
      Person.lease_connection.execute("DROP INDEX index_people_on_egd_pin")
      yield
    end
end
