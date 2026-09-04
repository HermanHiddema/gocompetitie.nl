class CreateSeasons < ActiveRecord::Migration[8.1]
  def change
    create_table :seasons do |t|
      t.string :name, null: false
      t.string :slug, null: false, index: { unique: true }
      t.text :information

      t.timestamps
    end
  end
end
