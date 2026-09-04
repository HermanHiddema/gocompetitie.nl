# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_04_234500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "clubs", force: :cascade do |t|
    t.string "abbrev"
    t.bigint "contact_person_id"
    t.datetime "created_at", null: false
    t.text "info"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["contact_person_id"], name: "index_clubs_on_contact_person_id"
  end

  create_table "games", force: :cascade do |t|
    t.bigint "black_id"
    t.integer "black_points"
    t.integer "board_number"
    t.datetime "created_at", null: false
    t.bigint "match_id", null: false
    t.string "reason"
    t.datetime "updated_at", null: false
    t.bigint "white_id"
    t.integer "white_points"
    t.index ["black_id"], name: "index_games_on_black_id"
    t.index ["match_id"], name: "index_games_on_match_id"
    t.index ["white_id"], name: "index_games_on_white_id"
  end

  create_table "leagues", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position"
    t.bigint "season_id", null: false
    t.datetime "updated_at", null: false
    t.index ["season_id"], name: "index_leagues_on_season_id"
  end

  create_table "matches", force: :cascade do |t|
    t.bigint "black_team_id", null: false
    t.datetime "created_at", null: false
    t.bigint "league_id", null: false
    t.date "playing_date"
    t.string "playing_time"
    t.datetime "updated_at", null: false
    t.bigint "venue_id"
    t.bigint "white_team_id", null: false
    t.index "league_id, LEAST(black_team_id, white_team_id), GREATEST(black_team_id, white_team_id)", name: "index_matches_on_league_and_team_pair", unique: true
    t.index ["black_team_id"], name: "index_matches_on_black_team_id"
    t.index ["league_id"], name: "index_matches_on_league_id"
    t.index ["venue_id"], name: "index_matches_on_venue_id"
    t.index ["white_team_id"], name: "index_matches_on_white_team_id"
  end

  create_table "participants", force: :cascade do |t|
    t.bigint "club_id"
    t.datetime "created_at", null: false
    t.string "egd_pin"
    t.string "firstname", null: false
    t.string "lastname", null: false
    t.bigint "person_id"
    t.integer "rank"
    t.integer "rating"
    t.bigint "season_id", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id"], name: "index_participants_on_club_id"
    t.index ["person_id"], name: "index_participants_on_person_id"
    t.index ["season_id"], name: "index_participants_on_season_id"
  end

  create_table "people", force: :cascade do |t|
    t.bigint "club_id"
    t.datetime "created_at", null: false
    t.string "egd_pin"
    t.string "email"
    t.string "email2"
    t.string "firstname", null: false
    t.string "lastname", null: false
    t.string "phone"
    t.string "phone2"
    t.integer "rating"
    t.datetime "updated_at", null: false
    t.index ["club_id"], name: "index_people_on_club_id"
  end

  create_table "seasons", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "information"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_seasons_on_slug", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "team_members", force: :cascade do |t|
    t.integer "board_number", null: false
    t.datetime "created_at", null: false
    t.bigint "participant_id", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["participant_id"], name: "index_team_members_on_participant_id"
    t.index ["team_id"], name: "index_team_members_on_team_id"
    t.unique_constraint ["participant_id"], deferrable: :deferred
    t.unique_constraint ["team_id", "board_number"], deferrable: :deferred
  end

  create_table "teams", force: :cascade do |t|
    t.string "abbrev", null: false
    t.bigint "captain_id"
    t.bigint "club_id", null: false
    t.datetime "created_at", null: false
    t.bigint "league_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["captain_id"], name: "index_teams_on_captain_id"
    t.index ["club_id"], name: "index_teams_on_club_id"
    t.index ["league_id"], name: "index_teams_on_league_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "venues", force: :cascade do |t|
    t.string "address", null: false
    t.string "city", null: false
    t.bigint "club_id", null: false
    t.datetime "created_at", null: false
    t.text "info"
    t.string "name", null: false
    t.integer "playing_day", null: false
    t.string "playing_time", null: false
    t.datetime "updated_at", null: false
    t.index ["club_id"], name: "index_venues_on_club_id"
  end

  add_foreign_key "clubs", "people", column: "contact_person_id"
  add_foreign_key "games", "matches"
  add_foreign_key "games", "participants", column: "black_id"
  add_foreign_key "games", "participants", column: "white_id"
  add_foreign_key "leagues", "seasons"
  add_foreign_key "matches", "leagues"
  add_foreign_key "matches", "teams", column: "black_team_id"
  add_foreign_key "matches", "teams", column: "white_team_id"
  add_foreign_key "matches", "venues"
  add_foreign_key "participants", "clubs"
  add_foreign_key "participants", "people"
  add_foreign_key "participants", "seasons"
  add_foreign_key "people", "clubs"
  add_foreign_key "sessions", "users"
  add_foreign_key "team_members", "participants"
  add_foreign_key "team_members", "teams"
  add_foreign_key "teams", "clubs"
  add_foreign_key "teams", "leagues"
  add_foreign_key "teams", "people", column: "captain_id"
  add_foreign_key "venues", "clubs"
end
