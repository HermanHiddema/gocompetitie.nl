class Match < ApplicationRecord
  BOARD_COUNT = 3
  belongs_to :league
  belongs_to :venue, optional: true
  belongs_to :home_team, class_name: "Team", inverse_of: :home_matches
  belongs_to :away_team, class_name: "Team", inverse_of: :away_matches

  has_many :games, dependent: :destroy

  accepts_nested_attributes_for :games

  validates :home_team, :away_team, :league, presence: true
  validate :teams_are_distinct
  validate :teams_belong_to_league
  validate :team_pair_is_unique

  delegate :name, :address, :city, :club, :playing_time, :playing_day, to: :venue, prefix: true, allow_nil: true
  delegate :season, to: :league, allow_nil: true
  delegate :handicap_adjustment, to: :season, allow_nil: true

  after_create :fill_games

  scope :scheduled, -> { order(:playing_date, :playing_time) }

  def self.find_by_teams(team1, team2)
    find_by_team_ids(team1.id, team2.id) if team1 && team2
  end

  def self.find_by_team_ids(team1_id, team2_id)
    find_by(home_team_id: team1_id, away_team_id: team2_id) ||
      find_by(home_team_id: team2_id, away_team_id: team1_id)
  end

  def fill_games
    (1..BOARD_COUNT).each do |board_number|
      home = home_team.team_members.find_by(board_number: board_number)
      away = away_team.team_members.find_by(board_number: board_number)
      games.create(
        board_number: board_number,
        home_player: home&.participant,
        away_player: away&.participant
      )
    end
  end

  def swap_sides
    self.home_team, self.away_team = away_team, home_team
    games.each(&:swap_sides)
    save
  end

  def opponent(team)
    case team.id
    when home_team_id then away_team
    when away_team_id then home_team
    end
  end

  def played?
    games.any?(&:played?)
  end

  def home_score
    winner_score(home_points, away_points)
  end

  def away_score
    winner_score(away_points, home_points)
  end

  def home_points
    points_for(:home_points)
  end

  def away_points
    points_for(:away_points)
  end

  def result
    [home_points, away_points].map { |points| points ? format("%g", points) : "?" }.join("-")
  end

  def to_s
    "#{home_team.name} - #{away_team.name}"
  end

  private
    def points_for(column)
      games.filter_map(&column).sum / 2.0 if played?
    end

    def winner_score(points, opponent_points)
      return unless played?
      return 0.5 if points == opponent_points
      points > opponent_points ? 1 : 0
    end

    def teams_are_distinct
      errors.add(:away_team, "must be different from the home team") if home_team_id.present? && home_team_id == away_team_id
    end

    def teams_belong_to_league
      [home_team, away_team].compact.each do |team|
        errors.add(:league, "teams must belong to the league") if league && team.league_id != league_id
      end
    end

    def team_pair_is_unique
      return unless league && home_team_id && away_team_id

      duplicate = league.matches.where.not(id: id).where(
        "(home_team_id = :home AND away_team_id = :away) OR (home_team_id = :away AND away_team_id = :home)",
        home: home_team_id, away: away_team_id
      ).exists?
      errors.add(:base, "teams already have a match in this league") if duplicate
    end
end
