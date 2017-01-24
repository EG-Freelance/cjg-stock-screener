class AddStrikeAndExpiration < ActiveRecord::Migration
  def change
    change_table :portfolio_items do |t|
      t.decimal :op_strike
      t.string :op_expiration
    end
  end
end
