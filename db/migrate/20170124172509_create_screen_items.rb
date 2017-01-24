class CreateScreenItems < ActiveRecord::Migration
  def change
    create_table :screen_items do |t|
      t.belongs_to :stock
      
      t.decimal :net_stock_issues
      t.decimal :rel_accruals
      t.decimal :net_op_assets_scaled
      t.decimal :assets_growth
      t.decimal :invest_to_assets
      t.decimal :adj_invest_to_assets
      t.decimal :l_52_wk_price
      t.decimal :profit_prem
      t.decimal :roa_q
      t.decimal :dist_total_2

      t.timestamps null: false
    end
  end
end
