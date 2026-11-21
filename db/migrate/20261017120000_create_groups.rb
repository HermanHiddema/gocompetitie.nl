# Teams no longer belong to a club directly but to a group of a season, which
# is linked to any number of clubs. Existing seasons are backfilled with a group
# for every club that fielded a team in them.
class CreateGroups < ActiveRecord::Migration[8.1]
  def up
    create_table :groups do |t|
      t.references :season, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :groups, %i[season_id name], unique: true

    create_table :group_memberships do |t|
      t.references :group, null: false, foreign_key: true, index: false
      t.references :club, null: false, foreign_key: true
      t.timestamps
    end
    add_index :group_memberships, %i[group_id club_id], unique: true

    add_reference :teams, :group, foreign_key: true

    execute <<~SQL
      INSERT INTO groups (season_id, name, created_at, updated_at)
      SELECT DISTINCT leagues.season_id, clubs.name, NOW(), NOW()
      FROM teams
      JOIN leagues ON leagues.id = teams.league_id
      JOIN clubs ON clubs.id = teams.club_id
    SQL

    execute <<~SQL
      INSERT INTO group_memberships (group_id, club_id, created_at, updated_at)
      SELECT DISTINCT groups.id, teams.club_id, NOW(), NOW()
      FROM teams
      JOIN leagues ON leagues.id = teams.league_id
      JOIN clubs ON clubs.id = teams.club_id
      JOIN groups ON groups.season_id = leagues.season_id AND groups.name = clubs.name
    SQL

    execute <<~SQL
      UPDATE teams SET group_id = groups.id
      FROM leagues, clubs, groups
      WHERE leagues.id = teams.league_id
        AND clubs.id = teams.club_id
        AND groups.season_id = leagues.season_id
        AND groups.name = clubs.name
    SQL

    change_column_null :teams, :group_id, false
    remove_reference :teams, :club, foreign_key: true, index: true
  end

  def down
    if select_value("SELECT COUNT(*) FROM teams WHERE NOT EXISTS (SELECT 1 FROM group_memberships WHERE group_memberships.group_id = teams.group_id)").to_i.positive?
      raise ActiveRecord::IrreversibleMigration, "Er zijn teams van een club zonder gekoppelde club."
    end

    add_reference :teams, :club, foreign_key: true

    execute <<~SQL
      UPDATE teams SET club_id = (
        SELECT MIN(group_memberships.club_id) FROM group_memberships WHERE group_memberships.group_id = teams.group_id
      )
    SQL

    change_column_null :teams, :club_id, false
    remove_reference :teams, :group, foreign_key: true, index: true
    drop_table :group_memberships
    drop_table :groups
  end
end
