class RenameGameAndMatchColorsToSides < ActiveRecord::Migration[8.1]
  def change
    rename_column :matches, :black_team_id, :home_team_id
    rename_column :matches, :white_team_id, :away_team_id

    rename_column :games, :black_id, :home_id
    rename_column :games, :white_id, :away_id
    rename_column :games, :black_points, :home_points
    rename_column :games, :white_points, :away_points
  end
end
