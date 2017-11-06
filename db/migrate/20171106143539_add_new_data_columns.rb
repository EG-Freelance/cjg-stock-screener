class AddNewDataColumns < ActiveRecord::Migration
  def change
    add_column :screen_items, :p_to_b_curr, :float
    add_column :screen_items, :ent_val_ov_focf, :float
    add_column :screen_items, :p_to_b_lyq, :float
    add_column :display_items, :p_to_b_curr, :float
    add_column :display_items, :ent_val_ov_focf, :float
    add_column :display_items, :p_to_b_lyq, :float
    add_column :transaction_items, :p_to_b_curr_o, :float
    add_column :transaction_items, :ent_val_ov_focf_o, :float
    add_column :transaction_items, :p_to_b_lyq_o, :float
    add_column :transaction_items, :p_to_b_curr_c, :float
    add_column :transaction_items, :ent_val_ov_focf_c, :float
    add_column :transaction_items, :p_to_b_lyq_c, :float
  end
end
