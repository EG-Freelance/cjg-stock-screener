class CreateMarginableSecurities < ActiveRecord::Migration
  def change
    create_table :marginable_securities do |t|
      t.decimal :amount

      t.timestamps null: false
    end
  end
end
