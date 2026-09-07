class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.references :match, null: false, foreign_key: true
      t.references :black, foreign_key: { to_table: :participants }
      t.references :white, foreign_key: { to_table: :participants }
      t.integer :black_points
      t.integer :white_points
      t.string :reason
      t.integer :board_number

      t.timestamps
    end
  end
end
