class CreateActions < ActiveRecord::Migration
  def change
    create_table :actions do |t|
      t.belongs_to :stock
      
      t.string :description

      t.timestamps null: false
    end
  end
end
