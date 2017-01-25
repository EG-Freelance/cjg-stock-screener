class AddCommonTimeStampToPortfolioAndScreenItems < ActiveRecord::Migration
  def change
    add_column :screen_items, :set_created_at, :datetime
    add_column :portfolio_items, :set_created_at, :dateti
  end
end
