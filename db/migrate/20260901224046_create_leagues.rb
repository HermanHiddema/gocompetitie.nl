class CreateLeagues < ActiveRecord::Migration[8.1]
  def change
    create_table :leagues do |t|
      t.string :name, null: false
      t.integer :position
      t.references :season, null: false, foreign_key: true

      t.timestamps
    end
  end
end
