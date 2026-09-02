class Match < ApplicationRecord
  BOARD_COUNT = 3
  belongs_to :league
  belongs_to :venue, optional: true
  belongs_to :black_team, class_name: "Team", inverse_of: :black_matches
  belongs_to :white_team, class_name: "Team", inverse_of: :white_matches

  has_many :games, dependent: :destroy

  accepts_nested_attributes_for :games

  validates :black_team, :white_team, :league, presence: true
  validate :teams_are_distinct
  validate :teams_belong_to_league

  delegate :name, :address, :city, :club, :playing_time, :playing_day, to: :venue, prefix: true, allow_nil: true

  after_create :fill_games

  scope :scheduled, -> { order(:playing_date, :playing_time) }

  def self.find_by_teams(team1, team2)
    find_by_team_ids(team1.id, team2.id) if team1 && team2
  end

  def self.find_by_team_ids(team1_id, team2_id)
    find_by(black_team_id: team1_id, white_team_id: team2_id) ||
      find_by(black_team_id: team2_id, white_team_id: team1_id)
  end

  def fill_games
    (1..BOARD_COUNT).each do |board_number|
      black = black_team.team_members.find_by(board_number: board_number)
      white = white_team.team_members.find_by(board_number: board_number)
      games.create(
        board_number: board_number,
        black_player: black&.participant,
        white_player: white&.participant
      )
    end
  end

  def swap_colors
    self.black_team, self.white_team = white_team, black_team
    games.each(&:swap_colors)
    save
  end

  def opponent(team)
    case team.id
    when black_team_id then white_team
    when white_team_id then black_team
    end
  end

  def played?
    games.any?(&:played?)
  end

  def black_score
    winner_score(black_points, white_points)
  end

  def white_score
    winner_score(white_points, black_points)
  end

  def black_points
    points_for(:black_points)
  end

  def white_points
    points_for(:white_points)
  end

  def result
    [ black_points, white_points ].map { |points| points ? format("%g", points) : "?" }.join("-")
  end

  def to_s
    "#{black_team.name} - #{white_team.name}"
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
      errors.add(:white_team, "must be different from black team") if black_team_id.present? && black_team_id == white_team_id
    end

    def teams_belong_to_league
      [black_team, white_team].compact.each do |team|
        errors.add(:league, "teams must belong to the league") if league && team.league_id != league_id
      end
    end
end
