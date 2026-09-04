class Season < ApplicationRecord
  has_many :leagues, -> { ordered }, dependent: :destroy, inverse_of: :season
  has_many :teams, through: :leagues
  has_many :matches, through: :leagues
  has_many :participants, dependent: :destroy
  has_many :games, through: :matches

  validates :name, presence: true
  validates :slug, uniqueness: true, allow_blank: true

  before_validation :update_slug

  scope :recent, -> { order(created_at: :desc) }

  def update_slug
    self.slug = name.to_s.gsub(/[^A-Za-z0-9]/, "-").downcase
  end

  def ranked_teams
    leagues.ordered.flat_map(&:ranked_teams)
  end

  def results
    ResultsExport.new(ordered_participants: ordered_participants, games: games.includes(:black_player, :white_player), group_names: ranked_teams.map(&:name)).lines
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

  def to_s
    name
  end

  private
    def ordered_participants
      team_participants = leagues.ordered.flat_map do |league|
        league.ranked_teams.map do |team|
          team.team_members.includes(:participant).by_board.map(&:participant)
        end
      end

      reserves = participants.includes(:club).select { |participant| participant.played_games.any? }
        .sort_by { |participant| -participant.rating_change }

      team_participants + [reserves - team_participants.flatten]
    end
end
