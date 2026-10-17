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
# The teams of a season are fielded by groups, which are shown as clubs in the
# interface. Usually a group is a single club, but clubs can field teams
# together and teams can be formed without any club at all, so a group is
# linked to any number of clubs. This can change from season to season, so
# every season has groups of its own.
class Group < ApplicationRecord
  belongs_to :season

  has_many :group_memberships, dependent: :delete_all
  has_many :clubs, through: :group_memberships
  has_many :venues, through: :clubs
  has_many :teams, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :season_id }

  scope :ordered, -> { order(:name) }

  def to_s
    name
  end
end
