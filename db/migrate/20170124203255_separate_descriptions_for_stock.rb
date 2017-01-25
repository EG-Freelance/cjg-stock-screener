class SeparateDescriptionsForStock < ActiveRecord::Migration
  def change
    remove_column :stocks, :description
    add_column :stocks, :si_description, :string
    add_column :stocks, :pi_description, :string
  end
end
