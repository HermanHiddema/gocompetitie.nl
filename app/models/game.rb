class Game < ApplicationRecord
  RESULTS = ["?-?", "1-0", "0-1", "½-½", "1-0!", "0-1!", "0-0"].freeze

  POINTS = { "0" => 0, "½" => 1, "1" => 2 }.freeze
  POINT_LABELS = POINTS.invert.freeze

  belongs_to :match
  belongs_to :black_player, class_name: "Participant", foreign_key: :black_id, optional: true, inverse_of: :black_games
  belongs_to :white_player, class_name: "Participant", foreign_key: :white_id, optional: true, inverse_of: :white_games

  validates :board_number, presence: true, inclusion: { in: 1..Match::BOARD_COUNT }, uniqueness: { scope: :match_id }
  validate :players_are_distinct
  validate :players_are_unique_in_match
  validate :players_play_in_the_season

  delegate :rating, to: :black_player, prefix: :black, allow_nil: true
  delegate :rating, to: :white_player, prefix: :white, allow_nil: true

  scope :played, -> { where.not(black_points: nil).where.not(white_points: nil) }
  scope :by_board, -> { order(:board_number) }

  def played?
    black_points.present? && white_points.present?
  end

  def unplayed?
    !played?
  end

  # A game without points for either player is not a game that was played on
  # the board, so it is treated like a forfeit: unrated and not exported.
  def forfeit?
    reason.present? || (played? && black_points.zero? && white_points.zero?)
  end

  def players?
    black_player.present? && white_player.present?
  end

  def swap_colors
    self.black_points, self.white_points = white_points, black_points
    self.black_player, self.white_player = white_player, black_player
    save
  end

  def color_of(player)
    return :black if black_player&.id == player.id
    return :white if white_player&.id == player.id
    nil
  end

  def result
    "#{POINT_LABELS.fetch(black_points, "?")}-#{POINT_LABELS.fetch(white_points, "?")}#{reason}"
  end

  def result=(value)
    value = value.to_s
    if RESULTS.include?(value) && (match = /\A([0½1?])-([0½1?])(!?)\z/.match(value))
      self.black_points = POINTS[match[1]]
      self.white_points = POINTS[match[2]]
      self.reason = match[3] == "!" ? "!" : nil
    else
      self.black_points = nil
      self.white_points = nil
      self.reason = nil
    end
  end

  def black_score
    score_for(black_points, white_points)
  end

  def white_score
    score_for(white_points, black_points)
  end

  def black_result
    result_symbol(black_score)
  end

  def white_result
    result_symbol(white_score)
  end

  # Rating change according to the EGF rating formula, expressed as the
  # difference between the achieved and the expected score.
  def black_rating_change
    rated? ? black_score - black_score_exp : 0
  end

  def white_rating_change
    rated? ? white_score - white_score_exp : 0
  end

  def black_score_exp
    score_exp(white_rating - black_rating)
  end

  def white_score_exp
    score_exp(black_rating - white_rating)
  end

  private
    def rated?
      played? && !forfeit? && players? && black_rating.present? && white_rating.present?
    end

    def players_are_distinct
      errors.add(:white_player, "must be different from black player") if black_id.present? && black_id == white_id
    end

    def players_are_unique_in_match
      return unless match_id.present?

      existing_player_ids = match.games.where.not(id: id).pluck(:black_id, :white_id).flatten.compact
      { black_player: black_id, white_player: white_id }.each do |attribute, player_id|
        errors.add(attribute, "must be unique in the match") if player_id.present? && existing_player_ids.include?(player_id)
      end
    end

    def players_play_in_the_season
      season_id = match&.league&.season_id
      return if season_id.blank?

      { black_player: black_player, white_player: white_player }.each do |attribute, player|
        errors.add(attribute, "must play in the season of the match") if player && player.season_id != season_id
      end
    end

    def score_exp(rating_difference)
      weaker_rating = [black_rating, white_rating].min
      a = 200 - (weaker_rating - 100) / 20.0 # a from the EGF GoR formula
      1.0 / (Math.exp(rating_difference / a) + 1)
    end

    def score_for(points, opponent_points)
      return 0 unless played?

      case points <=> opponent_points
      when 1 then 1
      when -1 then 0
      else 0.5
      end
    end

    def result_symbol(score)
      return "?" if unplayed?

      case score
      when 1 then "+"
      when 0 then "-"
      else "="
      end
    end
end
