class Club < ApplicationRecord
  belongs_to :contact_person, class_name: "Person", optional: true, inverse_of: :contacted_clubs

  has_many :people, dependent: :nullify
  has_many :participants, dependent: :nullify
  has_many :teams, dependent: :restrict_with_error
  has_many :venues, dependent: :restrict_with_error

  validates :name, presence: true

  scope :ordered, -> { order(:name) }
  scope :named, -> { where("LENGTH(name) > 4") }
  # A club takes part in a season when it fields a team or has a player in it.
  scope :in_season, ->(season) {
    where(id: Team.where(league: season.leagues).select(:club_id))
      .or(where(id: Participant.where(season: season).select(:club_id)))
  }

  def to_s
    name
  end
end
