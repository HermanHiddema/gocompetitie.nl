class TeamMember < ApplicationRecord
  belongs_to :team
  belongs_to :participant

  validates :board_number, presence: true, inclusion: { in: 1..Match::BOARD_COUNT }
  validate :board_number_is_unique_in_team
  validate :participant_plays_in_one_team
  validate :participant_belongs_to_team_season

  delegate :name, :fullname, :lastname, :firstname, :rating, to: :participant

  scope :by_board, -> { order(:board_number) }

  private
    def board_number_is_unique_in_team
      return if board_number.blank?

      errors.add(:board_number, "must be unique in the team") if other_members.any? { |member| member.board_number == board_number }
    end

    def participant_plays_in_one_team
      return if participant_id.blank?

      duplicate = other_members.any? { |member| member.participant_id == participant_id } ||
        TeamMember.where(participant_id: participant_id).where.not(team_id: team_id).exists?
      errors.add(:participant, "can only play in one team") if duplicate
    end

    # The other members of the team, preferring the records of the association
    # over their stored counterparts, so a nested update sees the new board
    # numbers and players of its siblings instead of the values they still
    # have in the database.
    def other_members
      return [] if team.blank?

      members = team.team_members.target.reject { |member| member.equal?(self) || member.marked_for_destruction? }
      return members if team.team_members.loaded?

      known_ids = (team.team_members.target.map(&:id) + [id]).compact
      members + team.team_members.where.not(id: known_ids).to_a
    end

    def participant_belongs_to_team_season
      return if participant.blank? || team.blank? || team.league.blank?
      return if participant.season_id == team.league.season_id

      errors.add(:participant, "must belong to the team's season")
    end
end
