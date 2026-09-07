class CreateMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :matches do |t|
      t.references :league, null: false, foreign_key: true
      t.references :black_team, null: false, foreign_key: { to_table: :teams }
      t.references :white_team, null: false, foreign_key: { to_table: :teams }
      t.date :playing_date
      t.string :playing_time
      t.references :venue, foreign_key: true

      t.timestamps
    end
  end
end
