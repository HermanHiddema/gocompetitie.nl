class Season < ApplicationRecord
  # Seasons are drafted, then played and finally closed. A finished season is
  # read only and only admins see the seasons that are still a draft.
  PHASES = %w[draft active finished].freeze

  enum :phase, PHASES.index_by(&:itself), default: :draft, validate: true

  has_many :leagues, -> { ordered }, dependent: :destroy, inverse_of: :season
  has_many :teams, through: :leagues
  has_many :matches, through: :leagues
  has_many :participants, dependent: :destroy
  has_many :games, through: :matches

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :handicap_adjustment, numericality: { only_integer: true, in: Game::HANDICAPS }, allow_nil: true
  validate :only_one_active_season

  before_validation :update_slug

  scope :with_slug, -> { where.not(slug: [nil, ""]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :published, -> { where.not(phase: :draft) }

  def self.preload_statistics(seasons)
    statistics = statistics_for(seasons)
    empty_statistics = { leagues: 0, clubs: 0, teams: 0, participants: 0 }

    seasons.each do |season|
      season.instance_variable_set(:@statistics, statistics.fetch(season.id, empty_statistics))
    end
  end

  def self.statistics_for(seasons)
    season_ids = seasons.map(&:id)
    statistics = season_ids.to_h { |id| [id, { leagues: 0, clubs: 0, teams: 0, participants: 0 }] }
    return statistics if season_ids.empty?

    League.where(season_id: season_ids).group(:season_id).count.each do |season_id, count|
      statistics[season_id][:leagues] = count
    end

    Team.joins(:league).where(leagues: { season_id: season_ids }).group("leagues.season_id").count.each do |season_id, count|
      statistics[season_id][:teams] = count
    end

    Team.joins(:league).where(leagues: { season_id: season_ids }).group("leagues.season_id").distinct.count(:club_id).each do |season_id, count|
      statistics[season_id][:clubs] = count
    end

    Participant.joins("INNER JOIN games ON games.home_id = participants.id OR games.away_id = participants.id")
      .where(season_id: season_ids).group(:season_id).distinct.count(:id).each do |season_id, count|
      statistics[season_id][:participants] = count
    end

    statistics
  end

  # The season the site shows by default: the season that is being played, or
  # the season that was finished most recently.
  def self.current
    with_slug.active.recent.first || with_slug.finished.order(updated_at: :desc, created_at: :desc).first
  end

  def start!
    transition_to!(:active, from: :draft)
  end

  # Games without a result in both columns, which are set to 0-0 when the
  # season is finished.
  def unplayed_games
    games.where(home_points: nil).or(games.where(away_points: nil))
  end

  # Participants that never appeared on a board and play in no team, which are
  # removed when the season is finished.
  def gameless_participants
    participants.where.missing(:team_member)
      .where.not(id: games.where.not(home_id: nil).select(:home_id))
      .where.not(id: games.where.not(away_id: nil).select(:away_id))
  end

  # Finishing a season closes its results, so the games that were never played
  # are recorded as 0-0 and the participants without any game or team are
  # deleted.
  def finish!
    transaction do
      ensure_transition_from!(:active, action: "afgesloten")
      unplayed_games.update_all(home_points: 0, away_points: 0, reason: nil, updated_at: Time.current)
      gameless_participants.destroy_all
      update!(phase: :finished)
    end
  end

  # Results may only be changed while the season is being played or prepared.
  def editable?
    !finished?
  end

  def update_slug
    self.slug = name.to_s.parameterize
  end

  def handicaps?
    handicap_adjustment.present?
  end

  # Counts for the seasons list: its leagues and teams, the clubs that field a
  # team and the participants with at least one game played or scheduled.
  def statistics
    return @statistics if instance_variable_defined?(:@statistics)

    {
      leagues: leagues.count,
      clubs: Club.where(id: teams.select(:club_id)).count,
      teams: teams.count,
      participants: participants.where(id: games.select(:home_id))
        .or(participants.where(id: games.select(:away_id))).count
    }
  end

  def ranked_teams
    leagues.ordered.flat_map(&:ranked_teams)
  end

  def results
    ResultsExport.new(
      ordered_participants: ordered_participants,
      games: games.includes(:home_player, :away_player, match: { league: :season }),
      group_names: ranked_teams.map(&:name)
    ).lines
  end

  def create_leagues(amount = 5)
    amount.times { |position| create_league(position) }
  end

  def create_league(position)
    leagues.create(name: League.name_for_position(position), position: position)
  end

  # Imports players from an European Go Database tournament export.
  def upsert_players(json_file)
    egd_data = JSON.parse(File.read(json_file))

    ActiveRecord::Base.transaction do
      egd_data["players"].each do |player|
        club = Club.find_by(abbrev: player["Club"]) || Club.create!(name: player["Club"], abbrev: player["Club"])
        person = Person.find_or_initialize_by(egd_pin: player["Pin_Player"])
        person.update!(
          rating: player["Gor"].to_i,
          lastname: player["Real_Last_Name"],
          firstname: player["Real_Name"],
          club: club
        )

        participant = participants.find_or_initialize_by(person: person)
        participant.rank = player["Grade"]
        participant.copy_person_attributes
        participant.save!
      end
    end
  end

  def to_param
    slug
  end

  def to_s
    name
  end

  private
    def transition_to!(phase, from:)
      ensure_transition_from!(from, action: phase == :active ? "gestart" : "afgesloten")
      update!(phase: phase)
    rescue ActiveRecord::RecordNotUnique
      errors.add(:phase, "is al in gebruik door een ander seizoen")
      raise ActiveRecord::RecordInvalid, self
    end

    def ensure_transition_from!(phase, action:)
      return if public_send("#{phase}?")

      errors.add(:base, "Alleen een seizoen in de fase #{phase} kan worden #{action}.")
      raise ActiveRecord::RecordInvalid, self
    end

    def only_one_active_season
      return unless active?

      errors.add(:phase, "is al in gebruik door een ander seizoen") if Season.active.where.not(id: id).exists?
    end

    def ordered_participants
      team_participants = leagues.ordered.flat_map do |league|
        league.ranked_teams.map do |team|
          team.team_members.includes(:participant).by_board.map(&:participant)
        end
      end

      reserves = participants.includes(:club, :home_games, :away_games).select { |participant| participant.played_games.any? }
        .sort_by { |participant| -participant.rating_change }

      team_participants + [reserves - team_participants.flatten]
    end
end
