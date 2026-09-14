class Venue < ApplicationRecord
  DAYS = %w[zondag maandag dinsdag woensdag donderdag vrijdag zaterdag].freeze

  belongs_to :club

  has_many :matches, dependent: :nullify

  validates :name, :address, :city, :playing_time, presence: true
  validates :playing_day, presence: true, inclusion: { in: 0..6 }

  scope :ordered, -> { order(:city, :name) }
  # A venue belongs to a season when its club takes part in it, or when a match
  # of the season is played there.
  scope :in_season, ->(season) {
    where(club: Club.in_season(season))
      .or(where(id: Match.where(league: season.leagues).select(:venue_id)))
  }

  def playing_day_name
    DAYS[playing_day] if playing_day
  end

  def to_s
    name
  end
end
