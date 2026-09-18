class Game < ApplicationRecord
  RESULTS = ["?-?", "1-0", "0-1", "½-½", "1-0!", "0-1!", "0-0"].freeze

  POINTS = { "0" => 0, "½" => 1, "1" => 2 }.freeze
  POINT_LABELS = POINTS.invert.freeze

  HANDICAPS = (0..9).freeze

  belongs_to :match
  belongs_to :home_player, class_name: "Participant", foreign_key: :home_id, optional: true, inverse_of: :home_games
  belongs_to :away_player, class_name: "Participant", foreign_key: :away_id, optional: true, inverse_of: :away_games

  before_validation :clear_handicap_if_players_change_without_handicaps

  validates :board_number, presence: true, inclusion: { in: 1..Match::BOARD_COUNT }, uniqueness: { scope: :match_id }
  validates :handicap, numericality: { only_integer: true, in: HANDICAPS }, allow_nil: true, if: :handicap_entered?
  validate :entered_handicap_within_default
  validate :handicap_allowed, if: :will_save_change_to_handicap?
  validate :players_are_distinct
  validate :players_are_unique_in_match
  validate :players_play_in_the_season

  delegate :rating, to: :home_player, prefix: :home, allow_nil: true
  delegate :rating, to: :away_player, prefix: :away, allow_nil: true

  scope :played, -> { where.not(home_points: nil).where.not(away_points: nil) }
  scope :by_board, -> { order(:board_number) }

  def played?
    home_points.present? && away_points.present?
  end

  def unplayed?
    !played?
  end

  # A game without points for either player is not a game that was played on
  # the board, so it is treated like a forfeit: unrated and not exported.
  def forfeit?
    reason.present? || (played? && home_points.zero? && away_points.zero?)
  end

  def players?
    home_player.present? && away_player.present?
  end

  # A rated game is played on the board by two players with a rating, so it
  # counts for the rating calculation and is included in the rated game report.
  def rated?
    played? && !forfeit? && players? && home_rating.present? && away_rating.present?
  end

  def swap_sides
    self.home_points, self.away_points = away_points, home_points
    self.home_player, self.away_player = away_player, home_player
    save
  end

  def side_of(player)
    return :home if home_player&.id == player.id
    return :away if away_player&.id == player.id
    nil
  end

  # The colors are not stored: with a handicap the weaker player takes black,
  # otherwise the home team plays black on the odd boards and white on the
  # even ones.
  def home_color
    if handicap.positive? && home_rating.present? && away_rating.present? && home_rating != away_rating
      home_rating < away_rating ? :black : :white
    else
      board_number.to_i.odd? ? :black : :white
    end
  end

  def away_color
    home_color == :black ? :white : :black
  end

  def color_of(player)
    side = side_of(player)
    public_send(:"#{side}_color") if side
  end

  def black_player
    home_color == :black ? home_player : away_player
  end

  def white_player
    home_color == :black ? away_player : home_player
  end

  def black_result
    home_color == :black ? home_result : away_result
  end

  def white_result
    home_color == :black ? away_result : home_result
  end

  # The handicap of the game, defaulting to the handicap that follows from the
  # rating difference of the players.
  def handicap
    return 0 if handicap_adjustment.nil?

    self[:handicap] || default_handicap
  end

  # The handicap as it was entered, nil when the default handicap is used.
  def entered_handicap
    self[:handicap] if handicap_adjustment.present?
  end

  # The rating difference minus 300 points, divided by 100 and rounded to the
  # nearest whole number, rounding halves down.
  def default_handicap
    return 0 if handicap_adjustment.nil? || home_rating.blank? || away_rating.blank?

    handicap = (((home_rating - away_rating).abs - handicap_adjustment * 100) / 100.0).round(half: :down)
    handicap.clamp(HANDICAPS.min, HANDICAPS.max)
  end

  # The color and handicap of a player as they are written in the result list
  # of the European Go Database, e.g. "/w3" for white with three stones.
  def egd_handicap(color)
    "/#{color == :black ? "b" : "w"}#{handicap}"
  end

  def home_handicap
    egd_handicap(home_color)
  end

  def away_handicap
    egd_handicap(away_color)
  end

  def result
    "#{POINT_LABELS.fetch(home_points, "?")}-#{POINT_LABELS.fetch(away_points, "?")}#{reason}"
  end

  def result=(value)
    value = value.to_s
    if RESULTS.include?(value) && (match = /\A([0½1?])-([0½1?])(!?)\z/.match(value))
      self.home_points = POINTS[match[1]]
      self.away_points = POINTS[match[2]]
      self.reason = match[3] == "!" ? "!" : nil
    else
      self.home_points = nil
      self.away_points = nil
      self.reason = nil
    end
  end

  def home_score
    score_for(home_points, away_points)
  end

  def away_score
    score_for(away_points, home_points)
  end

  def home_result
    result_symbol(home_score)
  end

  def away_result
    result_symbol(away_score)
  end

  # The rating a player enters the game with, where the player who receives the
  # handicap stones is credited 100 rating points per stone. Those stones are
  # given to black, who is the weaker player whenever there is a handicap.
  def home_handicap_rating
    handicap_rating(home_rating, home_color)
  end

  def away_handicap_rating
    handicap_rating(away_rating, away_color)
  end

  # Rating change according to the EGF rating formula, expressed as the
  # difference between the achieved and the expected score.
  def home_rating_change
    rated? ? home_score - home_score_exp : 0
  end

  def away_rating_change
    rated? ? away_score - away_score_exp : 0
  end

  def home_score_exp
    score_exp(away_handicap_rating - home_handicap_rating)
  end

  def away_score_exp
    score_exp(home_handicap_rating - away_handicap_rating)
  end

  private
    def players_are_distinct
      errors.add(:away_player, "must be different from the home player") if home_id.present? && home_id == away_id
    end

    def players_are_unique_in_match
      return if match.blank?

      player_ids = other_player_ids
      { home_player: home_id, away_player: away_id }.each do |attribute, player_id|
        errors.add(attribute, "must be unique in the match") if player_id.present? && player_ids.include?(player_id)
      end
    end

    # The other games of the match, preferring the records of the association
    # over their stored counterparts, so a nested update sees the new players
    # of its sibling games instead of the values they still have in the
    # database.
    def other_games
      games = match.games.target.reject { |game| game.equal?(self) || game.marked_for_destruction? }
      return games if match.games.loaded?

      known_ids = (match.games.target.map(&:id) + [id]).compact
      games + match.games.where.not(id: known_ids).to_a
    end

    def other_player_ids
      other_games.flat_map { |game| [game.home_id, game.away_id] }.compact
    end

    def players_play_in_the_season
      season_id = match&.league&.season_id
      return if season_id.blank?

      { home_player: home_player, away_player: away_player }.each do |attribute, player|
        errors.add(attribute, "must play in the season of the match") if player && player.season_id != season_id
      end
    end

    def handicap_entered?
      self[:handicap].present? || handicap_before_type_cast.present?
    end

    def handicap_adjustment
      match&.handicap_adjustment
    end

    def clear_handicap_if_players_change_without_handicaps
      self[:handicap] = nil if handicap_adjustment.nil? && (will_save_change_to_home_id? || will_save_change_to_away_id?)
    end

    def handicap_allowed
      errors.add(:handicap, "is not available for this season") if handicap_entered? && handicap_adjustment.nil?
    end

    def entered_handicap_within_default
      return if errors.include?(:handicap) || entered_handicap.blank? || entered_handicap <= default_handicap

      errors.add(:handicap, "must be at most #{default_handicap}")
    end

    def handicap_rating(rating, color)
      return rating if rating.blank? || color == :white

      rating + 100 * handicap
    end

    def score_exp(rating_difference)
      weaker_rating = [home_rating, away_rating].min
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
