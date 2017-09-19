class CreateTransactionItems < ActiveRecord::Migration
  def change
    create_table :transaction_items do |t|
      t.date :date_acq
      t.date :date_sold
      t.string :company
      t.string :symbol
      t.string :exchange
      t.integer :quantity
      t.decimal :paid
      t.decimal :last
      t.string :rec_action_o
      t.string :rec_action_c
      t.integer :total_score_o
      t.integer :total_score_c
      t.decimal :total_score_pct_o
      t.decimal :total_score_pct_c
      t.integer :nsi_score_o
      t.integer :nsi_score_c
      t.integer :ra_score_o
      t.integer :ra_score_c
      t.integer :noas_score_o
      t.integer :noas_score_c
      t.integer :ag_score_o
      t.integer :ag_score_c
      t.integer :aita_score_o
      t.integer :aita_score_c
      t.integer :l52wp_score_o
      t.integer :l52wp_score_c
      t.integer :pp_score_o
      t.integer :pp_score_c
      t.integer :rq_score_o
      t.integer :rq_score_c
      t.integer :dt2_score_o
      t.integer :dt2_score_c
      t.integer :prev_ed_o
      t.integer :prev_ed_c
      t.float :next_ed_o
      t.float :next_ed_c
      t.integer :mkt_cap_o, limit: 8
      t.integer :mkt_cap_c, limit: 8
      t.integer :lq_revenue_o, limit: 8
      t.integer :lq_revenue_c, limit: 8
      t.string :position
      t.string :pos_type
      t.string :op_type
      t.decimal :op_strike
      t.string :op_expiration
      
      t.boolean :active

      t.timestamps null: false
    end
  end
end
