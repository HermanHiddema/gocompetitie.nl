class Team < ApplicationRecord
  belongs_to :club
  belongs_to :league
  belongs_to :captain, class_name: "Person", optional: true

  has_many :black_matches, class_name: "Match", foreign_key: :black_team_id, dependent: :destroy, inverse_of: :black_team
  has_many :white_matches, class_name: "Match", foreign_key: :white_team_id, dependent: :destroy, inverse_of: :white_team
  has_many :team_members, -> { by_board }, dependent: :destroy, inverse_of: :team
  has_many :participants, through: :team_members

  accepts_nested_attributes_for :team_members, allow_destroy: true, reject_if: ->(attributes) { attributes[:participant_id].blank? }

  delegate :name, to: :captain, prefix: true, allow_nil: true

  validates :name, :abbrev, presence: true
  validate :league_is_immutable_with_matches, on: :update
  validate :team_members_are_unique
  validate :team_members_are_valid

  scope :ordered, -> { order(:name) }

  def matches
    Match.where(black_team_id: id).or(Match.where(white_team_id: id))
  end

  def score
    matches.includes(:games).sum { |match| (match.black_team_id == id ? match.black_score : match.white_score).to_f }
  end

  def points
    matches.includes(:games).sum { |match| (match.black_team_id == id ? match.black_points : match.white_points).to_f }
  end

  def unplayed_matches
    matches.reject(&:played?).length
  end

  def placement_criteria
    [score, points, unplayed_matches, direct_comparison]
  end

  def direct_comparison
    0
  end

  def to_s
    name
  end

  private
    def league_is_immutable_with_matches
      errors.add(:league, "cannot be changed when matches are scheduled") if league_id_changed? && matches.exists?
    end

    def team_members_are_unique
      members = team_members.reject(&:marked_for_destruction?)
      errors.add(:base, "board numbers must be unique") if duplicates?(members.map(&:board_number))
      errors.add(:base, "participants can only play in one team") if duplicates?(members.map(&:participant_id))
    end

    def team_members_are_valid
      team_members.reject(&:marked_for_destruction?).each do |member|
        errors.add(:team_members, :invalid) unless member.valid?
      end
    end

    def duplicates?(values)
      values = values.compact
      values.length != values.uniq.length
    end
end
