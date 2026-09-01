class Person < ApplicationRecord
  belongs_to :club, optional: true

  has_many :participants, dependent: :nullify
  has_many :captained_teams, class_name: "Team", foreign_key: :captain_id, dependent: :nullify, inverse_of: :captain

  validates :firstname, :lastname, presence: true

  scope :ordered, -> { order(:firstname, :lastname) }

  def name
    "#{firstname.tr("_", " ")} #{lastname.tr("_", " ")}"
  end

  def to_s
    name
  end

  def email_addresses
    [ email, email2 ].compact_blank
  end

  def phone_numbers
    [ phone, phone2 ].compact_blank
  end
end
