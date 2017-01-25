module MathStuff
  extend ActiveSupport::Concern

	# median array for adj_invest_to_assets
  def self.median(dataset)
  	sorted = dataset.sort
  	len = sorted.length
  	return (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end
end
