class CreateTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.string :name, null: false
      t.string :abbrev, null: false
      t.references :club, null: false, foreign_key: true
      t.references :league, null: false, foreign_key: true
      t.references :captain, foreign_key: { to_table: :people }

      t.timestamps
    end
  end
end
