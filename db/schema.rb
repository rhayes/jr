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

ActiveRecord::Schema.define(version: 0) do

  create_table "dispenser_offsets", id: :integer, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "number", default: 0, null: false
    t.string "grade_type", limit: 15, default: "regular_cents", null: false
    t.integer "offset", default: 0, null: false
    t.date "start_date", null: false
  end

  create_table "dispenser_sales", id: :integer, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "week_id", null: false
    t.integer "number", default: 1, null: false
    t.integer "regular_cents", default: 0, null: false
    t.string "regular_currency", default: "USD", null: false
    t.decimal "regular_volume", precision: 12, scale: 3, default: "0.0", null: false
    t.integer "plus_cents", default: 0, null: false
    t.string "plus_currency", default: "USD", null: false
    t.decimal "plus_volume", precision: 12, scale: 3, default: "0.0", null: false
    t.integer "premium_cents", default: 0, null: false
    t.string "premium_currency", default: "USD", null: false
    t.decimal "premium_volume", precision: 12, scale: 3, default: "0.0", null: false
    t.integer "diesel_cents", default: 0, null: false
    t.string "diesel_currency", default: "USD", null: false
    t.decimal "diesel_volume", precision: 12, scale: 3, default: "0.0", null: false
    t.index ["number"], name: "number"
    t.index ["week_id", "number"], name: "unique_dispenser", unique: true
    t.index ["week_id"], name: "week_id"
  end

  create_table "fd", id: :integer, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "week_id", null: false
    t.date "delivery_date", null: false
    t.integer "invoice_number"
    t.integer "supreme_gallons", default: 0, null: false
    t.decimal "supreme_per_gallon", precision: 10, scale: 5, default: "0.0", null: false
    t.integer "regular_gallons", default: 0, null: false
    t.decimal "regular_per_gallon", precision: 10, scale: 5, default: "0.0", null: false
    t.integer "diesel_gallons", default: 0, null: false
    t.decimal "diesel_per_gallon", precision: 10, scale: 5, default: "0.0", null: false
    t.decimal "storage_tank_fee", precision: 10, scale: 5, default: "0.01", null: false
    t.integer "monthly_tank_charge_cents", default: 0, null: false
    t.string "monthly_tank_charge_currency", default: "USD", null: false
    t.integer "adjustment_cents", default: 0, null: false
    t.integer "transaction_id"
    t.index ["invoice_number"], name: "invoice_number", unique: true
    t.index ["week_id"], name: "week_id"
  end

  create_table "fuel_deliveries", id: :integer, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "week_id", null: false
    t.date "delivery_date", null: false
    t.integer "invoice_number", null: false
    t.integer "supreme_gallons", default: 0, null: false
    t.decimal "supreme_per_gallon", precision: 10, scale: 5, default: "0.0", null: false
    t.integer "regular_gallons", default: 0, null: false
    t.decimal "regular_per_gallon", precision: 10, scale: 5, default: "0.0", null: false
    t.integer "diesel_gallons", default: 0, null: false
    t.decimal "diesel_per_gallon", precision: 10, scale: 5, default: "0.0", null: false
    t.decimal "storage_tank_fee", precision: 10, scale: 5, default: "0.01", null: false
    t.integer "monthly_tank_charge_cents", default: 0, null: false
    t.string "monthly_tank_charge_currency", default: "USD", null: false
    t.integer "adjustment_cents", default: 0, null: false
    t.integer "transaction_id"
    t.index ["invoice_number"], name: "invoice_number", unique: true
    t.index ["transaction_id"], name: "transaction_id", unique: true
    t.index ["week_id"], name: "week_id"
  end

  create_table "loan_interests", id: :integer, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "tax_year", null: false
    t.integer "amount_cents", default: 0, null: false
    t.string "amount_currency", default: "USD", null: false
  end

  create_table "tank_volumes", id: :integer, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "week_id", default: 0, null: false
    t.integer "regular", default: 0, null: false
    t.integer "diesel", default: 0, null: false
    t.integer "premium", default: 0, null: false
    t.index ["week_id"], name: "week_id"
  end

  create_table "transactions", id: :integer, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.date "date", null: false
    t.integer "tax_year", default: 2018, null: false
    t.string "type_of", limit: 6, default: "Debit", null: false
    t.boolean "include", default: false, null: false
    t.string "check_number"
    t.integer "amount_cents", null: false
    t.string "amount_currency", default: "USD", null: false
    t.string "category", limit: 17, default: "not_set", null: false
    t.string "description", default: "", null: false
    t.integer "balance_cents", default: 0, null: false
    t.string "balance_currency", default: "USD"
  end

  create_table "weeks", id: :integer, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "number", null: false
    t.date "date", null: false
    t.integer "tax_year", default: 0
  end

  create_table "year_leases", id: :integer, default: nil, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "amount_cents"
    t.string "amount_currency", limit: 3, default: "USD"
  end

  add_foreign_key "dispenser_sales", "weeks", name: "weeks_sales", on_update: :cascade, on_delete: :cascade
  add_foreign_key "fd", "weeks", name: "tax_week_fd", on_update: :cascade, on_delete: :cascade
  add_foreign_key "fuel_deliveries", "weeks", name: "tax_week_fuel_deliveries", on_update: :cascade, on_delete: :cascade
  add_foreign_key "tank_volumes", "weeks", name: "weeks_tank_volumes", on_update: :cascade, on_delete: :cascade
end
