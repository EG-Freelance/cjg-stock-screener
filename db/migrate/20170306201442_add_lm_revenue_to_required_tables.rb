class AddLmRevenueToRequiredTables < ActiveRecord::Migration
  def change
    add_column :stocks, :lm_revenue, :integer
    add_column :display_items, :lm_revenue, :integer
  end
end
