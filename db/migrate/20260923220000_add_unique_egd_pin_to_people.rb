class AddUniqueEgdPinToPeople < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE people SET egd_pin = NULL WHERE BTRIM(egd_pin) = ''"
    Person.merge_egd_pin_duplicates!
    add_index :people, :egd_pin, unique: true
  end

  def down
    remove_index :people, :egd_pin
  end
end
