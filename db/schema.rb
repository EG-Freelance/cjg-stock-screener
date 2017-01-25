# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170124203255) do

  create_table "pages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "portfolio_items", force: :cascade do |t|
    t.integer  "stock_id"
    t.string   "position"
    t.string   "pos_type"
    t.string   "op_type"
    t.datetime "date_acq"
    t.integer  "quantity"
    t.decimal  "paid"
    t.decimal  "last"
    t.decimal  "change"
    t.decimal  "day_gain"
    t.decimal  "day_gain_p"
    t.decimal  "tot_gain"
    t.decimal  "tot_gain_p"
    t.decimal  "market_val"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.decimal  "op_strike"
    t.string   "op_expiration"
  end

  create_table "screen_items", force: :cascade do |t|
    t.integer  "stock_id"
    t.decimal  "net_stock_issues"
    t.decimal  "rel_accruals"
    t.decimal  "net_op_assets_scaled"
    t.decimal  "assets_growth"
    t.decimal  "invest_to_assets"
    t.decimal  "adj_invest_to_assets"
    t.decimal  "l_52_wk_price"
    t.decimal  "profit_prem"
    t.decimal  "roa_q"
    t.decimal  "dist_total_2"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  create_table "stocks", force: :cascade do |t|
    t.string   "exchange"
    t.string   "symbol"
    t.integer  "market_cap"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.string   "si_description"
    t.string   "pi_description"
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true

end
