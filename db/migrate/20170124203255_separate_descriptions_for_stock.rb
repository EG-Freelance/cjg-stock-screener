class SeparateDescriptionsForStock < ActiveRecord::Migration
  def change
    add_column :stocks, :si_description, :string
    add_column :stocks, :pi_description, :string
  end
end
