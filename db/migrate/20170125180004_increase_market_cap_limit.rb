class IncreaseMarketCapLimit < ActiveRecord::Migration
  def change
    change_column :stocks, :market_cap, :integer, limit: 8
  end
end
