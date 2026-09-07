class CreateTeamMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :team_members do |t|
      t.references :participant, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.integer :board_number, null: false

      t.timestamps
    end

    add_index :team_members, [:team_id, :board_number], unique: true
    add_index :team_members, :participant_id, unique: true
  end
end
