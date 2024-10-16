module Bucket::View::OrderBy
  extend ActiveSupport::Concern

  included do
    store_accessor :filters, :order_by
  end

  private
    ORDERS = {
      "most_active" => "most active",
      "most_discussed" => "most discussed",
      "most_boosted" => "most boosted",
      "newest" => "newest",
      "oldest" => "oldest" }
end
