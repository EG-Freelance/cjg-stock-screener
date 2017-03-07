class AddDisplayItemReferences < ActiveRecord::Migration
  def change
    add_reference :stocks, :display_item, index: true
  end
end
