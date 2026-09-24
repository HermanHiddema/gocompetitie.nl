class AddUniqueEgdPinToPeople < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class MigrationPerson < ApplicationRecord
    self.table_name = "people"

    has_many :participants, foreign_key: :person_id, dependent: :nullify
    has_many :captained_teams, class_name: "Team", foreign_key: :captain_id, dependent: :nullify, inverse_of: :captain
    has_many :contacted_clubs, class_name: "Club", foreign_key: :contact_person_id, dependent: :nullify, inverse_of: :contact_person

    def self.merge_egd_pin_duplicates!
      transaction do
        duplicate_egd_pins.sum do |egd_pin|
          target, *duplicates = where(egd_pin: egd_pin).order(updated_at: :desc, id: :desc).to_a
          duplicates.each { |duplicate| duplicate.merge_into!(target) }
          duplicates.size
        end
      end
    end

    def self.duplicate_egd_pins
      where.not(egd_pin: nil).group(:egd_pin).having("COUNT(*) > 1").pluck(:egd_pin)
    end

    def merge_into!(other)
      participants.update_all(person_id: other.id)
      captained_teams.update_all(captain_id: other.id)
      contacted_clubs.update_all(contact_person_id: other.id)
      destroy!
    end
  end

  def up
    MigrationPerson.transaction do
      execute "UPDATE people SET egd_pin = NULLIF(BTRIM(egd_pin), '')"
      MigrationPerson.merge_egd_pin_duplicates!
    end

    add_index :people, :egd_pin, unique: true, algorithm: :concurrently, if_not_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
