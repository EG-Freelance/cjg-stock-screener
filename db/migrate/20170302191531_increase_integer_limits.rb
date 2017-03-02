class IncreaseIntegerLimits < ActiveRecord::Migration
  def change
    change_column :display_items, :mkt_cap, :integer, limit: 8
  end
end
