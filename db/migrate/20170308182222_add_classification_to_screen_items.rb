class AddClassificationToScreenItems < ActiveRecord::Migration
  def change
    add_column :screen_items, :classification, :string
  end
end
