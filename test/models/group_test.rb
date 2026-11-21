require "test_helper"

# == Schema Information
#
# Table name: groups
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  season_id  :bigint           not null
#
# Indexes
#
#  index_groups_on_season_id_and_name  (season_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (season_id => seasons.id)
#
class GroupTest < ActiveSupport::TestCase
  test "a group requires a name that is unique within its season" do
    group = seasons(:current).groups.build(name: "Go Club Amsterdam")

    assert_not group.valid?
    assert group.errors.added?(:name, :taken, value: "Go Club Amsterdam")
    assert seasons(:previous).groups.build(name: "Go Club Amsterdam").valid?
    assert_not seasons(:current).groups.build(name: "").valid?
  end

  test "a group can be linked to no club or to several clubs" do
    season = seasons(:previous)

    university = season.groups.create!(name: "TU Delft")
    together = season.groups.create!(name: "Amsterdam/Utrecht", clubs: [clubs(:amsterdam), clubs(:utrecht)])

    assert_empty university.clubs
    assert_equal [clubs(:amsterdam), clubs(:utrecht)].sort, together.clubs.sort
    assert_equal [venues(:amsterdam), venues(:utrecht)].sort, together.venues.sort
  end

  test "a group with teams cannot be removed" do
    group = groups(:amsterdam)

    assert_not group.destroy
    assert Group.exists?(group.id)

    group.teams.destroy_all
    assert group.destroy
  end
end
