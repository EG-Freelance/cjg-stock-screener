class CreateEarningsDates < ActiveRecord::Migration
  def change
    create_table :earnings_dates do |t|
      t.belongs_to :stock
      
      t.string :time
      t.date :date

      t.timestamps null: false
    end
  end
end
