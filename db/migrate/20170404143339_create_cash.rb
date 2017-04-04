class CreateCash < ActiveRecord::Migration
  def change
    create_table :cashes do |t|
      t.decimal :amount
      
      t.timestamps
    end
  end
end
