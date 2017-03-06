class FixLqRevenueName < ActiveRecord::Migration
  def change
    rename_column :display_items, :lm_revenue, :lq_revenue
    rename_column :stocks, :lm_revenue, :lq_revenue
  end
end
