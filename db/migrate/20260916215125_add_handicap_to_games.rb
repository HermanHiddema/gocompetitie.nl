class AddHandicapToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :handicap, :integer
  end
end
