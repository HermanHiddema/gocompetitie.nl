class Participant < ApplicationRecord
  PERSON_ATTRIBUTES = %w[ club_id firstname lastname rating egd_pin ].freeze

  belongs_to :club, optional: true
  belongs_to :season
  belongs_to :person, optional: true

  has_one :team_member, dependent: :destroy
  has_one :team, through: :team_member
  has_many :black_games, class_name: "Game", foreign_key: :black_id, dependent: :nullify, inverse_of: :black_player
  has_many :white_games, class_name: "Game", foreign_key: :white_id, dependent: :nullify, inverse_of: :white_player

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
    Game.where(black_id: id).or(Game.where(white_id: id))
  end

  def played_games
    if black_games.loaded? && white_games.loaded?
      (black_games + white_games).select(&:played?)
    else
      games.played
    end
  end

  def rating_change
    black = black_games.loaded? ? black_games.select(&:played?) : black_games.played
    white = white_games.loaded? ? white_games.select(&:played?) : white_games.played
    black.sum(&:black_rating_change) + white.sum(&:white_rating_change)
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
