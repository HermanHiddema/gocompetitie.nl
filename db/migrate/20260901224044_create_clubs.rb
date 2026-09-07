class CreateClubs < ActiveRecord::Migration[8.1]
  def change
    create_table :clubs do |t|
      t.string :name, null: false
      t.string :abbrev
      t.string :website
      t.text :info
      t.references :contact_person, foreign_key: { to_table: :people }

      t.timestamps
    end

    add_foreign_key :people, :clubs
  end
end
