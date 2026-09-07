class CreateParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :participants do |t|
      t.string :firstname, null: false
      t.string :lastname, null: false
      t.integer :rating
      t.integer :rank
      t.string :egd_pin
      t.references :person, foreign_key: true
      t.references :club, foreign_key: true
      t.references :season, null: false, foreign_key: true

      t.timestamps
    end
  end
end
