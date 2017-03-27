class AddColumnToDisplayItem < ActiveRecord::Migration
  def change
    add_column :display_items, :curr_portfolio, :integer, limit: 8
  end
end
