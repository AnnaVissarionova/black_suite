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

ActiveRecord::Schema[8.0].define(version: 2025_12_19_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "experiments", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.bigint "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "share_token"
    t.integer "json_results_count", default: 0, null: false
    t.index ["created_at"], name: "index_experiments_on_created_at"
    t.index ["project_id", "created_at"], name: "index_experiments_on_project_id_and_created_at"
    t.index ["project_id"], name: "index_experiments_on_project_id"
    t.index ["share_token"], name: "index_experiments_on_share_token", unique: true
  end

  create_table "json_results", force: :cascade do |t|
    t.bigint "experiment_id", null: false
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_json_results_on_created_at"
    t.index ["experiment_id", "created_at"], name: "index_json_results_on_experiment_id_and_created_at"
    t.index ["experiment_id"], name: "index_json_results_on_experiment_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "share_token"
    t.string "share_mode", default: "private"
    t.integer "experiments_count", default: 0, null: false
    t.index ["created_at"], name: "index_projects_on_created_at"
    t.index ["share_token"], name: "index_projects_on_share_token", unique: true
    t.index ["user_id", "created_at"], name: "index_projects_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "experiments", "projects"
  add_foreign_key "json_results", "experiments"
  add_foreign_key "projects", "users"
end
