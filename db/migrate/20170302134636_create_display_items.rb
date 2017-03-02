class CreateDisplayItems < ActiveRecord::Migration
  def change
    create_table :display_items do |t|
      t.string :classification
      t.datetime :set_created_at
      t.string :symbol
      t.string :exchange
      t.string :company
      t.string :in_pf
      t.string :rec_action
      t.string :action
      t.integer :total_score
      t.decimal :total_score_pct
      t.string :dist_status
      t.integer :mkt_cap
      t.integer :nsi_score
      t.integer :ra_score
      t.integer :noas_score
      t.integer :ag_score
      t.integer :aita_score
      t.integer :l52wp_score
      t.integer :pp_score
      t.integer :rq_score
      t.integer :dt2_score
      t.integer :prev_ed
      t.integer :next_ed

      t.timestamps null: false
    end
  end
end
