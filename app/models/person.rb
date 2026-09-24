# == Schema Information
#
# Table name: people
#
#  id         :bigint           not null, primary key
#  egd_pin    :string
#  email      :string
#  email2     :string
#  firstname  :string           not null
#  lastname   :string           not null
#  phone      :string
#  phone2     :string
#  rating     :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  club_id    :bigint
#
# Indexes
#
#  index_people_on_club_id  (club_id)
#  index_people_on_egd_pin  (egd_pin) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (club_id => clubs.id)
#
class Person < ApplicationRecord
  belongs_to :club, optional: true

  has_many :participants, dependent: :nullify
  has_many :captained_teams, class_name: "Team", foreign_key: :captain_id, dependent: :nullify, inverse_of: :captain
  has_many :contacted_clubs, class_name: "Club", foreign_key: :contact_person_id, dependent: :nullify, inverse_of: :contact_person

  normalizes :egd_pin, with: ->(egd_pin) { egd_pin&.strip.presence }

  validates :firstname, :lastname, presence: true
  validates :egd_pin, uniqueness: true, allow_nil: true

  scope :ordered, -> { order(:firstname, :lastname) }

  # Merges the people that share an EGD pin into the one that was updated most
  # recently, so that a pin identifies a single person.
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

  # Reattaches everything that refers to this person to the other person and
  # deletes this person afterwards.
  def merge_into!(other)
    raise ArgumentError, "a person cannot be merged into itself" if other.id == id

    self.class.transaction do
      participants.update_all(person_id: other.id)
      captained_teams.update_all(captain_id: other.id)
      contacted_clubs.update_all(contact_person_id: other.id)
      destroy!
    end
  end

  def name
    "#{firstname.tr("_", " ")} #{lastname.tr("_", " ")}"
  end

  def to_s
    name
  end

  def email_addresses
    [email, email2].compact_blank
  end

  def phone_numbers
    [phone, phone2].compact_blank
  end
end
