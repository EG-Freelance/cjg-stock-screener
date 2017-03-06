class IncreaseIntegerRangeForLmRev < ActiveRecord::Migration
  def change
    change_column :stocks, :lm_revenue, :integer, limit: 8
    change_column :display_items, :lm_revenue, :integer, limit: 8
  end
end
