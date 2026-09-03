class AddUniqueTeamPairToMatches < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE UNIQUE INDEX index_matches_on_league_and_team_pair
      ON matches (league_id, LEAST(black_team_id, white_team_id), GREATEST(black_team_id, white_team_id))
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS index_matches_on_league_and_team_pair"
  end
end
