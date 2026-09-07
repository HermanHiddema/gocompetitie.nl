class MakeTeamMemberUniquenessDeferrable < ActiveRecord::Migration[8.1]
  def change
    remove_index :team_members, column: [:team_id, :board_number], unique: true
    remove_index :team_members, column: :participant_id, unique: true
    add_index :team_members, :participant_id

    # Deferred constraints let a team swap the board numbers or the players of
    # its members within one transaction.
    add_unique_constraint :team_members, [:team_id, :board_number], deferrable: :deferred
    add_unique_constraint :team_members, [:participant_id], deferrable: :deferred
  end
end
