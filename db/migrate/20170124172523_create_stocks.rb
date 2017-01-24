class CreateStocks < ActiveRecord::Migration
  def change
    create_table :stocks do |t|
      t.string :exchange
      t.string :symbol
      t.integer :market_cap

      t.timestamps null: false
    end
  end
end
