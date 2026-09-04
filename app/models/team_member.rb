class TeamMember < ApplicationRecord
  belongs_to :team
  belongs_to :participant

  validates :board_number, presence: true, inclusion: { in: 1..Match::BOARD_COUNT }, uniqueness: { scope: :team_id }
  validates :participant_id, uniqueness: true
  validate :participant_belongs_to_team_season

  delegate :name, :fullname, :lastname, :firstname, :rating, to: :participant

  scope :by_board, -> { order(:board_number) }

  private
    def participant_belongs_to_team_season
      return if participant.blank? || team.blank? || team.league.blank?
      return if participant.season_id == team.league.season_id

      errors.add(:participant, "must belong to the team's season")
    end
end
