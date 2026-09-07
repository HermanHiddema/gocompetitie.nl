class CreateVenues < ActiveRecord::Migration[8.1]
  def change
    create_table :venues do |t|
      t.references :club, null: false, foreign_key: true
      t.string :name, null: false
      t.string :address, null: false
      t.string :city, null: false
      t.integer :playing_day, null: false
      t.string :playing_time, null: false
      t.text :info

      t.timestamps
    end
  end
end
