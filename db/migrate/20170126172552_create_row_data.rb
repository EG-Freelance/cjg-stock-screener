class CreateRowData < ActiveRecord::Migration
  def change
    create_table :row_data do |t|
      t.belongs_to :data_set
      
      t.string :data
      t.integer :row_number
      t.string :data_type
    end
  end
end
