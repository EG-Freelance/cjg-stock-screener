class CreatePortfolioItems < ActiveRecord::Migration
  def change
    create_table :portfolio_items do |t|
      t.belongs_to :stock
      
      t.string :position
      t.string :pos_type
      t.string :op_type
      t.datetime :date_acq
      t.integer :quantity
      t.decimal :paid
      t.decimal :last
      t.decimal :change
      t.decimal :day_gain
      t.decimal :day_gain_p
      t.decimal :tot_gain
      t.decimal :tot_gain_p
      t.decimal :market_val

      t.timestamps null: false
    end
  end
end
