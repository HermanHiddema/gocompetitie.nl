# == Schema Information
#
# Table name: participants
#
#  id         :bigint           not null, primary key
#  egd_pin    :string
#  firstname  :string           not null
#  lastname   :string           not null
#  rank       :integer
#  rating     :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  club_id    :bigint
#  person_id  :bigint
#  season_id  :bigint           not null
#
# Indexes
#
#  index_participants_on_club_id    (club_id)
#  index_participants_on_person_id  (person_id)
#  index_participants_on_season_id  (season_id)
#
# Foreign Keys
#
#  fk_rails_...  (club_id => clubs.id)
#  fk_rails_...  (person_id => people.id)
#  fk_rails_...  (season_id => seasons.id)
#
class Participant < ApplicationRecord
  PERSON_ATTRIBUTES = %w[club_id firstname lastname rating egd_pin].freeze

  belongs_to :club, optional: true
  belongs_to :season
  belongs_to :person, optional: true

  has_one :team_member, dependent: :destroy
  has_one :team, through: :team_member
  has_many :home_games, -> { includes(match: { league: :season }) },
    class_name: "Game", foreign_key: :home_id, dependent: :nullify, inverse_of: :home_player
  has_many :away_games, -> { includes(match: { league: :season }) },
    class_name: "Game", foreign_key: :away_id, dependent: :nullify, inverse_of: :away_player

  validates :firstname, :lastname, presence: true

  scope :by_rating, -> { order(rating: :desc) }

  def copy_person_attributes
    assign_attributes(person.attributes.slice(*PERSON_ATTRIBUTES))
  end

  def name
    "#{fullname} (#{rating})"
  end

  def fullname
    "#{firstname.tr("_", " ")} #{lastname.tr("_", " ")}"
  end

  def games
    Game.where(home_id: id).or(Game.where(away_id: id))
  end

  def played_games
    if home_games.loaded? && away_games.loaded?
      (home_games + away_games).select(&:played?)
    else
      games.played
    end
  end

  def rating_change
    home = home_games.loaded? ? home_games.select(&:played?) : home_games.played
    away = away_games.loaded? ? away_games.select(&:played?) : away_games.played
    home.sum(&:home_rating_change) + away.sum(&:away_rating_change)
  end

  def rating_performance
    "#{(rating_change * 100).round(2)}%"
  end

  # Ranks are stored as an integer so they can be sorted:
  #   1..50 => 50k..1k, 51..59 => 1d..9d, 60 => pro, 61..69 => 1p..9p
  def rank=(value)
    value = value.to_i if value.to_s.match?(/\A\d+\z/)

    self[:rank] = case value
    when 1..69 then value
    when /\A([1-9])\s*(dan)?\s*p\z/i then Regexp.last_match(1).to_i + 60
    when /\Apro\z/i then 60
    when /\A([1-9])\s*d\z/i then Regexp.last_match(1).to_i + 50
    when /\A([1-9]|[1-4]\d|50)\s*k(?:yu)?\z/i then 51 - Regexp.last_match(1).to_i
    else 0
    end
  end

  def rank
    case self[:rank]
    when 61..69 then "#{self[:rank] - 60}p"
    when 60 then "pro"
    when 51..59 then "#{self[:rank] - 50}d"
    when 1..50 then "#{51 - self[:rank]}k"
    else ""
    end
  end

  def to_s
    fullname
  end
end
