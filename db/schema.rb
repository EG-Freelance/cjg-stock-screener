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

ActiveRecord::Schema.define(version: 20171106143539) do

  create_table "actions", force: :cascade do |t|
    t.integer  "stock_id"
    t.string   "description"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "cashes", force: :cascade do |t|
    t.decimal  "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "data_sets", force: :cascade do |t|
  end

  create_table "display_items", force: :cascade do |t|
    t.string   "classification"
    t.datetime "set_created_at"
    t.string   "symbol"
    t.string   "exchange"
    t.string   "company"
    t.string   "in_pf"
    t.string   "rec_action"
    t.string   "action"
    t.integer  "total_score"
    t.decimal  "total_score_pct"
    t.string   "dist_status"
    t.integer  "mkt_cap",         limit: 8
    t.integer  "nsi_score"
    t.integer  "ra_score"
    t.integer  "noas_score"
    t.integer  "ag_score"
    t.integer  "aita_score"
    t.integer  "l52wp_score"
    t.integer  "pp_score"
    t.integer  "rq_score"
    t.integer  "dt2_score"
    t.string   "prev_ed"
    t.string   "next_ed"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.integer  "lq_revenue",      limit: 8
    t.integer  "rec_portfolio",   limit: 8
    t.integer  "net_portfolio",   limit: 8
    t.integer  "curr_portfolio",  limit: 8
    t.float    "p_to_b_curr"
    t.float    "ent_val_ov_focf"
    t.float    "p_to_b_lyq"
  end

  create_table "earnings_dates", force: :cascade do |t|
    t.integer  "stock_id"
    t.string   "time"
    t.date     "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "marginable_securities", force: :cascade do |t|
    t.decimal  "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

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
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.decimal  "op_strike"
    t.string   "op_expiration"
    t.date     "set_created_at"
  end

  create_table "row_data", force: :cascade do |t|
    t.integer "data_set_id"
    t.string  "data"
    t.integer "row_number"
    t.string  "data_type"
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
    t.datetime "set_created_at"
    t.string   "classification"
    t.float    "p_to_b_curr"
    t.float    "ent_val_ov_focf"
    t.float    "p_to_b_lyq"
  end

  create_table "stocks", force: :cascade do |t|
    t.string   "exchange"
    t.string   "symbol"
    t.integer  "market_cap",      limit: 8
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.string   "si_description"
    t.string   "pi_description"
    t.integer  "lq_revenue",      limit: 8
    t.integer  "display_item_id"
  end

  add_index "stocks", ["display_item_id"], name: "index_stocks_on_display_item_id"

  create_table "transaction_items", force: :cascade do |t|
    t.date     "date_acq"
    t.date     "date_sold"
    t.string   "company"
    t.string   "symbol"
    t.string   "exchange"
    t.integer  "quantity"
    t.decimal  "paid"
    t.decimal  "last"
    t.string   "rec_action_o"
    t.string   "rec_action_c"
    t.integer  "total_score_o"
    t.integer  "total_score_c"
    t.decimal  "total_score_pct_o"
    t.decimal  "total_score_pct_c"
    t.integer  "nsi_score_o"
    t.integer  "nsi_score_c"
    t.integer  "ra_score_o"
    t.integer  "ra_score_c"
    t.integer  "noas_score_o"
    t.integer  "noas_score_c"
    t.integer  "ag_score_o"
    t.integer  "ag_score_c"
    t.integer  "aita_score_o"
    t.integer  "aita_score_c"
    t.integer  "l52wp_score_o"
    t.integer  "l52wp_score_c"
    t.integer  "pp_score_o"
    t.integer  "pp_score_c"
    t.integer  "rq_score_o"
    t.integer  "rq_score_c"
    t.integer  "dt2_score_o"
    t.integer  "dt2_score_c"
    t.integer  "prev_ed_o"
    t.integer  "prev_ed_c"
    t.float    "next_ed_o"
    t.float    "next_ed_c"
    t.integer  "mkt_cap_o",         limit: 8
    t.integer  "mkt_cap_c",         limit: 8
    t.integer  "lq_revenue_o",      limit: 8
    t.integer  "lq_revenue_c",      limit: 8
    t.string   "position"
    t.string   "pos_type"
    t.string   "op_type"
    t.decimal  "op_strike"
    t.string   "op_expiration"
    t.boolean  "active"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.float    "p_to_b_curr_o"
    t.float    "ent_val_ov_focf_o"
    t.float    "p_to_b_lyq_o"
    t.float    "p_to_b_curr_c"
    t.float    "ent_val_ov_focf_c"
    t.float    "p_to_b_lyq_c"
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
