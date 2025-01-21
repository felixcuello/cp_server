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

ActiveRecord::Schema[7.2].define(version: 2025_01_20_125905) do
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
    t.string "constraints", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tags", charset: "utf8", force: :cascade do |t|
    t.string "name", null: false
  end

  create_table "users", charset: "utf8", force: :cascade do |t|
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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "examples", "problems"
  add_foreign_key "problem_tags", "problems"
  add_foreign_key "problem_tags", "tags"
end
