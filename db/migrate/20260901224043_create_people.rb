class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.string :firstname, null: false
      t.string :lastname, null: false
      t.string :egd_pin
      t.integer :rating
      t.references :club, index: true
      t.string :email
      t.string :email2
      t.string :phone
      t.string :phone2

      t.timestamps
    end
  end
end
