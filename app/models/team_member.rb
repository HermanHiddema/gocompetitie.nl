class TeamMember < ApplicationRecord
  belongs_to :team
  belongs_to :participant

  validates :board_number, presence: true, inclusion: { in: 1..Match::BOARD_COUNT }, uniqueness: { scope: :team_id }
  validates :participant_id, uniqueness: true

  delegate :name, :fullname, :lastname, :firstname, :rating, to: :participant

  scope :by_board, -> { order(:board_number) }
end
