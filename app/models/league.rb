# == Schema Information
#
# Table name: leagues
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  position   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  season_id  :bigint           not null
#
# Indexes
#
#  index_leagues_on_season_id  (season_id)
#
# Foreign Keys
#
#  fk_rails_...  (season_id => seasons.id)
#
class League < ApplicationRecord
  NAMES = [
    "Hoofdklasse",
    "Eerste klasse",
    "Tweede klasse",
    "Derde klasse",
    "Vierde klasse",
    "Vijfde klasse",
    "Zesde klasse",
    "Zevende klasse",
    "Achtste klasse",
    "Negende klasse",
    "Tiende klasse"
  ].freeze

  # A single cell of the cross table: the match between two teams, the points
  # scored by the team on the row and whether that team won, lost or has not
  # played yet.
  Standing = Struct.new(:match, :points, :status, :venue)

  belongs_to :season

  has_many :teams, dependent: :destroy
  has_many :matches, dependent: :destroy
  has_many :games, through: :matches

  validates :name, presence: true

  scope :ordered, -> { order(:position) }

  def self.name_for_position(position)
    NAMES[position] || "Poule #{position + 1}"
  end

  # Teams are ranked by match points and board points. Teams that are still
  # tied are separated by their mutual results, see #break_tie.
  def ranked_teams
    criteria = teams.to_a.to_h { |team| [team, team.placement_criteria] }
    sorted = criteria.keys.sort_by { |team| criteria[team] }.reverse
    sorted.chunk_while { |team, other| criteria[team] == criteria[other] }
          .flat_map { |tied| break_tie(tied, Match::BOARD_COUNT) }
  end

  # The players of the teams in the league, plus the substitutes that were
  # fielded in it. Substitutes that are a member of a team are left out, they are
  # already listed with their own team.
  def participants
    members = Participant.joins(:team_member).where(team_members: { team_id: teams.select(:id) })
    substitutes = Participant.where.missing(:team_member)
    substitutes = substitutes.where(id: games.select(:home_id)).or(substitutes.where(id: games.select(:away_id)))

    Participant.where(id: members).or(Participant.where(id: substitutes))
  end

  # Cross table of the league: standings[team][opponent] holds the result of
  # their mutual match, or nil when no match has been scheduled.
  def standings
    @standings ||= matches.each_with_object({}) do |match, table|
      table[match.home_team_id] ||= {}
      table[match.away_team_id] ||= {}
      table[match.home_team_id][match.away_team_id] = standing_for(match, :home)
      table[match.away_team_id][match.home_team_id] = standing_for(match, :away)
    end
  end

  def standing(team, opponent)
    standings.dig(team.id, opponent.id)
  end

  def make_pairing(weeks = nil)
    weeks ||= Array.new([teams.length - 1 + (teams.length.odd? ? 1 : 0), 1].max) { |i| Date.today + 14 * (i + 1) }
    pairing = self.class.round_robin_pairing(teams.to_a)
    return if pairing.nil?

    pairing.each_with_index do |pairs, round|
      pairs.each do |home, away|
        next if home.nil? || away.nil?

        venue = home.club.venues.first || Venue.first
        if venue
          base_date = weeks[round]
          iso_day = venue.playing_day.zero? ? 7 : venue.playing_day
          if base_date.is_a?(Integer)
            playing_date = Date.commercial(Date.today.year, base_date, iso_day)
          else
            playing_date = base_date + ((iso_day - base_date.cwday) % 7)
          end
        end
        matches.create(home_team: home, away_team: away, venue: venue, playing_date: playing_date, playing_time: venue&.playing_time)
      end
    end
  end

  def drop_pairing
    matches.destroy_all
  end

  # Berger tables: every team plays every other team once, alternating colors.
  def self.round_robin_pairing(participants)
    return nil if participants.length < 3

    participants = participants.dup
    participants << nil if participants.length.odd?

    boards = participants.length / 2
    fixed = participants.shift

    Array.new(participants.length) do |index|
      participants.unshift(fixed)
      round = Array.new(boards) do |board|
        if index.odd?
          [participants[board], participants[-board - 1]]
        else
          [participants[-board - 1], participants[board]]
        end
      end
      participants.shift
      participants.rotate!(-1)
      round
    end
  end

  def results
    ResultsExport.new(
      ordered_participants: ordered_participants,
      games: games.includes(:home_player, :away_player, match: { league: :season }),
      group_names: ranked_teams.map(&:name)
    ).lines
  end

  def to_s
    name
  end

  private
    # Tied teams are separated by the match points and board points they scored
    # against each other. Teams that remain tied are compared again on the
    # results of their mutual matches with the last board removed, then the
    # last two boards, and so on. Teams that are still tied when no boards are
    # left keep their current order.
    def break_tie(tied, boards)
      return tied if tied.length < 2 || boards < 1

      criteria = mutual_criteria(tied, boards)
      tied.sort_by { |team| criteria[team.id] }.reverse
          .chunk_while { |team, other| criteria[team.id] == criteria[other.id] }
          .flat_map do |group|
            group.length == tied.length ? break_tie(group, boards - 1) : break_tie(group, Match::BOARD_COUNT)
          end
    end

    # The match points and board points the tied teams scored against each
    # other, counting only the games on the first given number of boards.
    def mutual_criteria(tied, boards)
      team_ids = tied.map(&:id)
      criteria = team_ids.index_with { [0.0, 0.0] }

      matches.includes(:games).each do |match|
        next unless team_ids.include?(match.home_team_id) && team_ids.include?(match.away_team_id)

        games = match.games.select { |game| game.board_number <= boards && game.played? }
        next if games.empty?

        home_points = games.sum { |game| game.home_points.to_f } / 2.0
        away_points = games.sum { |game| game.away_points.to_f } / 2.0
        criteria[match.home_team_id] = add_result(criteria[match.home_team_id], home_points, away_points)
        criteria[match.away_team_id] = add_result(criteria[match.away_team_id], away_points, home_points)
      end

      criteria
    end

    def add_result(criteria, points, opponent_points)
      score = case points <=> opponent_points
      when 1 then 1.0
      when -1 then 0.0
      else 0.5
      end

      [criteria.first + score, criteria.last + points]
    end

    def ordered_participants
      team_groups = ranked_teams.map { |team| team.team_members.includes(:participant).by_board.map(&:participant) }
      roster = team_groups.flatten
      reserves = games.includes(:home_player, :away_player).played.flat_map { |game| [game.home_player, game.away_player] }.compact.uniq - roster
      team_groups + (reserves.present? ? [reserves] : [])
    end

    def standing_for(match, color)
      points = match.played? ? match.public_send(:"#{color}_points") : nil
      status = if !match.played?
        "unplayed"
      elsif match.public_send(:"#{color}_score") == 1
        "won"
      elsif match.public_send(:"#{color}_score") == 0.5
        "draw"
      else
        "lost"
      end

      Standing.new(match, points, status, match.venue)
    end
end
