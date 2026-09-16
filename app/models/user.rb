class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  # Captains maintain the matches of their team, admins maintain everything.
  enum :role, { captain: "captain", admin: "admin" }, default: :captain, validate: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :password, length: { minimum: 8 }, allow_nil: true
end
