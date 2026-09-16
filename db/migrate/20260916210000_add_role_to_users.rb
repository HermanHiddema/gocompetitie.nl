class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :role, :string, null: false, default: "captain"

    # Team accounts have an @teams.gocompetitie.nl address, everybody else
    # administrated the competition and keeps being able to do so.
    execute <<~SQL.squish
      UPDATE users SET role = 'admin' WHERE email_address NOT LIKE '%teams.gocompetitie.nl'
    SQL

    remove_column :users, :admin
  end

  def down
    add_column :users, :admin, :boolean, null: false, default: false

    execute <<~SQL.squish
      UPDATE users SET admin = TRUE WHERE role = 'admin'
    SQL

    remove_column :users, :role
  end
end
