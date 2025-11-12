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

ActiveRecord::Schema[8.0].define(version: 2025_11_12_143558) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "customers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "country"
    t.datetime "created_at", null: false
    t.string "isin"
    t.string "name"
    t.string "stock_symbol"
    t.datetime "updated_at", null: false
  end

  create_table "mensa_table_views", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "config"
    t.string "name"
    t.string "table_name"
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.string "description"
    t.index ["config"], name: "index_mensa_table_views_on_config", using: :gin
    t.index ["table_name"], name: "index_mensa_table_views_on_table_name"
    t.index ["user_id"], name: "index_mensa_table_views_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "customer_id", null: false
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_users_on_customer_id"
  end

  add_foreign_key "mensa_table_views", "users"
  add_foreign_key "users", "customers"
end
