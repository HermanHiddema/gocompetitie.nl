# == Schema Information
#
# Table name: group_memberships
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  club_id    :bigint           not null
#  group_id   :bigint           not null
#
# Indexes
#
#  index_group_memberships_on_club_id               (club_id)
#  index_group_memberships_on_group_id_and_club_id  (group_id,club_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (club_id => clubs.id)
#  fk_rails_...  (group_id => groups.id)
#
class GroupMembership < ApplicationRecord
  belongs_to :group
  belongs_to :club

  validates :club_id, uniqueness: { scope: :group_id }
end
