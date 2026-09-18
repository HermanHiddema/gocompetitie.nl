class AddHandicapAdjustmentToSeasons < ActiveRecord::Migration[8.1]
  class Season < ActiveRecord::Base
  end

  def up
    add_column :seasons, :handicap_adjustment, :integer, default: 3

    Season.reset_column_information
    Season.find_each do |season|
      year = season.name.to_s[/\b\d{4}\b/].to_i
      season.update_column(:handicap_adjustment, nil) if year.positive? && year < 2025
    end
  end

  def down
    remove_column :seasons, :handicap_adjustment
  end
end
