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

ActiveRecord::Schema[7.2].define(version: 2025_11_23_000001) do
  create_table "constraints", charset: "utf8", force: :cascade do |t|
    t.bigint "problem_id", null: false
    t.text "description", null: false
    t.integer "sort_order", null: false
    t.index ["problem_id"], name: "index_constraints_on_problem_id"
  end

  create_table "contests", charset: "utf8", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.text "rules"
    t.datetime "start_time", null: false
    t.datetime "end_time", null: false
    t.integer "penalty_minutes", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["end_time"], name: "index_contests_on_end_time"
    t.index ["start_time"], name: "index_contests_on_start_time"
  end

  create_table "examples", charset: "utf8", force: :cascade do |t|
    t.text "input"
    t.text "output"
    t.integer "sort_order"
    t.boolean "is_hidden", default: true, null: false
    t.bigint "problem_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["problem_id"], name: "index_examples_on_problem_id"
  end

  create_table "problem_tags", charset: "utf8", force: :cascade do |t|
    t.bigint "problem_id", null: false
    t.bigint "tag_id", null: false
    t.index ["problem_id"], name: "index_problem_tags_on_problem_id"
    t.index ["tag_id"], name: "index_problem_tags_on_tag_id"
  end

  create_table "problems", charset: "utf8", force: :cascade do |t|
    t.string "title", null: false
    t.text "description", null: false
    t.integer "difficulty", null: false
    t.integer "memory_limit_kb", null: false
    t.integer "time_limit_sec", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "total_submissions", default: 0, null: false
    t.integer "accepted_submissions", default: 0, null: false
    t.index ["accepted_submissions"], name: "index_problems_on_accepted_submissions"
    t.index ["total_submissions"], name: "index_problems_on_total_submissions"
  end

  create_table "programming_languages", charset: "utf8", force: :cascade do |t|
    t.string "name", null: false
    t.string "compiler_binary"
    t.string "compiler_flags"
    t.string "interpreter_binary"
    t.string "interpreter_flags"
    t.integer "memory_limit_kb"
    t.integer "time_limit_sec"
    t.string "extension"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "submissions", charset: "utf8", force: :cascade do |t|
    t.bigint "problem_id", null: false
    t.bigint "programming_language_id", null: false
    t.bigint "user_id", null: false
    t.text "source_code", null: false
    t.text "compiler_output"
    t.text "interpreter_output"
    t.integer "memory_used"
    t.float "time_used"
    t.string "status", default: "queued", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["problem_id"], name: "index_submissions_on_problem_id"
    t.index ["programming_language_id"], name: "index_submissions_on_programming_language_id"
    t.index ["user_id"], name: "index_submissions_on_user_id"
  end

  create_table "tags", charset: "utf8", force: :cascade do |t|
    t.string "name", null: false
  end

  create_table "user_problem_statuses", charset: "utf8", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "problem_id", null: false
    t.string "status", null: false
    t.datetime "first_solved_at"
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["problem_id"], name: "index_user_problem_statuses_on_problem_id"
    t.index ["status"], name: "index_user_problem_statuses_on_status"
    t.index ["user_id", "problem_id"], name: "index_user_problem_statuses_on_user_id_and_problem_id", unique: true
    t.index ["user_id"], name: "index_user_problem_statuses_on_user_id"
  end

  create_table "users", charset: "utf8", force: :cascade do |t|
    t.string "alias", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "timeout_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "role", default: 0, null: false
    t.index ["alias"], name: "index_users_on_alias", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "constraints", "problems"
  add_foreign_key "examples", "problems"
  add_foreign_key "problem_tags", "problems"
  add_foreign_key "problem_tags", "tags"
  add_foreign_key "submissions", "problems"
  add_foreign_key "submissions", "programming_languages"
  add_foreign_key "submissions", "users"
  add_foreign_key "user_problem_statuses", "problems"
  add_foreign_key "user_problem_statuses", "users"
end
