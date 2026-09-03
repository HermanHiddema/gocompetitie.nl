class AddUniqueTeamPairToMatches < ActiveRecord::Migration[8.1]
  def change
    add_index :matches,
      "league_id, LEAST(black_team_id, white_team_id), GREATEST(black_team_id, white_team_id)",
      unique: true,
      name: "index_matches_on_league_and_team_pair"
  end
end
