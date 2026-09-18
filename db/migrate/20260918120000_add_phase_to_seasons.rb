class AddPhaseToSeasons < ActiveRecord::Migration[8.1]
  class Season < ActiveRecord::Base
  end

  def up
    add_column :seasons, :phase, :string, null: false, default: "draft"
    add_index :seasons, :phase
    add_index :seasons, :phase, unique: true, where: "phase = 'active'", name: "index_seasons_on_active_phase"

    Season.reset_column_information
    latest = Season.order(created_at: :desc).first
    Season.update_all(phase: "finished")
    latest&.update_column(:phase, "active")
  end

  def down
    remove_index :seasons, name: "index_seasons_on_active_phase"
    remove_index :seasons, :phase
    remove_column :seasons, :phase
  end
end
