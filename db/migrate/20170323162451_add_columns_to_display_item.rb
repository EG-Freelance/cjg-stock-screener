class AddColumnsToDisplayItem < ActiveRecord::Migration
  def change
    add_column :display_items, :rec_portfolio, :integer, limit: 8
    add_column :display_items, :net_portfolio, :integer, limit: 8
  end
end
