module Bucket::View::Status
  extend ActiveSupport::Concern

  included do
    store_accessor :filters, :status
  end

  private
    STATUSES = %w[ unassigned popped ].index_by(&:itself)
end
