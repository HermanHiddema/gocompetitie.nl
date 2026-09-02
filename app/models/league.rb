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

  def ranked_teams
    teams.to_a.sort_by(&:placement_criteria).reverse
  end

  def participants
    Participant.joins(:team_member).where(team_members: { team_id: teams.select(:id) })
  end

  # Cross table of the league: standings[team][opponent] holds the result of
  # their mutual match, or nil when no match has been scheduled.
  def standings
    @standings ||= matches.each_with_object({}) do |match, table|
      table[match.black_team_id] ||= {}
      table[match.white_team_id] ||= {}
      table[match.black_team_id][match.white_team_id] = standing_for(match, :black)
      table[match.white_team_id][match.black_team_id] = standing_for(match, :white)
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
        matches.create(black_team: home, white_team: away, venue: venue, playing_date: playing_date, playing_time: venue&.playing_time)
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
    ResultsExport.new(ordered_participants: ordered_participants, games: games.includes(:black_player, :white_player), group_names: ranked_teams.map(&:name)).lines
  end

  def to_s
    name
  end

  private
    def ordered_participants
      ranked_teams.map { |team| team.team_members.includes(:participant).by_board.map(&:participant) }
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
