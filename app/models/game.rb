class Game < ApplicationRecord
  RESULTS = [ "?-?", "1-0", "0-1", "1-0!", "0-1!", "0-0" ].freeze

  POINTS = { "0" => 0, "½" => 1, "1" => 2 }.freeze
  POINT_LABELS = POINTS.invert.freeze

  belongs_to :match
  belongs_to :black_player, class_name: "Participant", foreign_key: :black_id, optional: true, inverse_of: :black_games
  belongs_to :white_player, class_name: "Participant", foreign_key: :white_id, optional: true, inverse_of: :white_games

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

  def forfeit?
    reason.present?
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
    if (match = /\A(.)-(.)(!?)/.match(value.to_s))
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

    def score_exp(rating_difference)
      weaker_rating = [ black_rating, white_rating ].min
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
