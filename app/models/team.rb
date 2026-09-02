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

  scope :ordered, -> { order(:name) }

  def matches
    Match.where(black_team_id: id).or(Match.where(white_team_id: id))
  end

  def score
    (black_matches.map(&:black_score) + white_matches.map(&:white_score)).compact.sum
  end

  def points
    (black_matches.map(&:black_points) + white_matches.map(&:white_points)).compact.sum
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
end
