class CreateCashes < ActiveRecord::Migration
  def change
    drop_table :cashes
    
    create_table :cashes do |t|
      t.decimal :amount

      t.timestamps null: false
    end
  end
end
