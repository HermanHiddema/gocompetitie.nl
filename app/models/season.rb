# == Schema Information
#
# Table name: seasons
#
#  id                  :bigint           not null, primary key
#  handicap_adjustment :integer          default(3)
#  information         :text
#  name                :string           not null
#  phase               :string           default("draft"), not null
#  slug                :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_seasons_on_active_phase  (phase) UNIQUE WHERE ((phase)::text = 'active'::text)
#  index_seasons_on_phase         (phase)
#  index_seasons_on_slug          (slug) UNIQUE
#
class Season < ApplicationRecord
  # Seasons are drafted, then played and finally closed, or cancelled when they
  # cannot be played out. A finished or cancelled season is read only and only
  # admins see the seasons that are still a draft.
  PHASES = %w[draft active finished cancelled].freeze

  # Defaults of the import from the European Go Database: the Dutch players
  # that played a rated game in the past four years.
  EGD_COUNTRY_CODE = "NL".freeze
  EGD_ACTIVE_YEARS = 4

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
  scope :ended, -> { where(phase: %i[finished cancelled]) }

  def self.preload_statistics(seasons)
    statistics = statistics_for(seasons)
    empty_statistics = { leagues: 0, clubs: 0, teams: 0, participants: 0 }
    champions = champions_for(seasons.select(&:finished?))

    seasons.each do |season|
      season.instance_variable_set(:@statistics, statistics.fetch(season.id, empty_statistics))
      season.instance_variable_set(:@champion, champions.fetch(season.id, nil)) if season.finished?
    end
  end

  def self.champions_for(seasons)
    season_ids = seasons.map(&:id)
    return {} if season_ids.empty?

    first_league_ids = League.where(season_id: season_ids).order(:season_id, :position, :id).pluck(:season_id, :id)
      .each_with_object({}) do |(season_id, league_id), first_ids|
        first_ids[season_id] ||= league_id
      end

    League.where(id: first_league_ids.values).includes(matches: :games, teams: :league).index_by(&:season_id).transform_values do |league|
      league.ranked_teams.first
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
  # the season that ended most recently.
  def self.current
    with_slug.active.recent.first || with_slug.ended.order(updated_at: :desc, created_at: :desc).first
  end

  def start!
    transition_to!(:active, from: :draft, action: "gestart")
  end

  # Games without a result in both columns, which are set to 0-0 when the
  # season is finished.
  def unplayed_games
    games.where(home_points: nil).or(games.where(away_points: nil))
  end

  # Participants that never appeared on a board and play in no team, which are
  # removed when the season ends.
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

  # Cancelling a season ends it without a winner: the games that were never
  # played stay unplayed, only the participants without any game or team are
  # deleted.
  def cancel!
    transaction do
      ensure_transition_from!(:active, action: "geannuleerd")
      gameless_participants.destroy_all
      update!(phase: :cancelled)
    end
  end

  # A season that has ended keeps its results, whether it was finished or
  # cancelled.
  def ended?
    finished? || cancelled?
  end

  # Results may only be changed while the season is being played or prepared.
  def editable?
    !ended?
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

  # The team that won the highest league. A season only has a champion once it
  # has been finished, before that the standings can still change.
  def champion
    return unless finished?
    return @champion if instance_variable_defined?(:@champion)

    @champion = leagues.ordered.first&.ranked_teams&.first
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

  # Seeds the season with players from the European Go Database: by default the
  # Dutch players that appeared in a tournament in the past four years. See
  # docs/egd-graphql-api.md for the API this reads from.
  def import_egd_players(country_code: EGD_COUNTRY_CODE, years: EGD_ACTIVE_YEARS, client: Egd::Client.new)
    active_since = egd_active_since(years)
    players = client.players(filter: { countryCode: country_code })
      .select { |player| importable_egd_player?(player, active_since) }

    transaction do
      players.each { |player| upsert_egd_player(player) }
    end

    players.size
  end

  # Stores one player of the European Go Database as a person of this season,
  # reusing the person and the club that were imported earlier.
  def upsert_egd_player(player)
    person = Person.find_or_initialize_by(egd_pin: player["pin"].to_s)
    person.update!(
      firstname: player["firstName"],
      lastname: player["lastName"],
      rating: player["rating"],
      club: egd_club(player["club"])
    )

    participant = participants.find_or_initialize_by(person: person)
    participant.copy_person_attributes
    participant.rank = player["grade"]
    participant.save!
    participant
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
    def egd_active_since(years)
      return if years.nil?

      years = Integer(years)
      raise Egd::Error, "YEARS moet een positief aantal jaren zijn" unless years.positive?

      years.years.ago.to_date
    rescue ArgumentError, TypeError
      raise Egd::Error, "YEARS moet een positief aantal jaren zijn"
    end

    # Players without a name or a PIN cannot be stored, and unless every player
    # is wanted only those that appeared in a tournament since the given date
    # are imported. The API documents no format for its dates, so a date that
    # cannot be read counts as no appearance at all.
    def importable_egd_player?(player, active_since)
      return false if player["pin"].blank? || player["firstName"].blank? || player["lastName"].blank?
      return true if active_since.nil?

      last_appearance = egd_date(player["lastAppearance"])
      last_appearance.present? && last_appearance >= active_since
    end

    def egd_date(value)
      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def egd_club(abbrev)
      return if abbrev.blank?

      Club.find_by(abbrev: abbrev) || Club.create!(name: abbrev, abbrev: abbrev)
    end

    def transition_to!(phase, from:, action:)
      ensure_transition_from!(from, action: action)
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
