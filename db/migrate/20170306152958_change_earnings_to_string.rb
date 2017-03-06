class ChangeEarningsToString < ActiveRecord::Migration
  def change
    change_column :display_items, :prev_ed, :string
    change_column :display_items, :next_ed, :string
  end
end
