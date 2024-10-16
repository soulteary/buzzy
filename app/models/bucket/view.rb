class Bucket::View < ApplicationRecord
  include Assignees, OrderBy, Status, Summarized, Tags

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :bucket

  has_one :account, through: :creator

  validate :must_have_filters, :must_not_be_the_default_view

  def to_bucket_params
    filters.compact_blank
  end

  private
    def must_have_filters
      errors.add(:base, "must have filters") if filters.values.all?(&:blank?)
    end

    def must_not_be_the_default_view
      errors.add(:base, "must be different than the default view") if filters.compact_blank == { "order_by" => "most_active" }
    end
end
