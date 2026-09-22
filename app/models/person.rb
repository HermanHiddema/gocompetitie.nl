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

  validates :firstname, :lastname, presence: true

  scope :ordered, -> { order(:firstname, :lastname) }

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
