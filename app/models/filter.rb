class Filter < ApplicationRecord
  include Params, Resources, Summarized

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  has_one :account, through: :creator

  class << self
    def persist!(attrs)
      filter = new(attrs)
      filter.save!
      filter
    rescue ActiveRecord::RecordNotUnique
      find_by!(params: filter.params).tap(&:touch) # possible thanks to denormalized params
    end
  end

  def bubbles
    @bubbles ||= begin
      result = creator.accessible_bubbles.indexed_by(indexed_by)
      result = result.active unless indexed_by.popped?
      result = result.unassigned if assignments.unassigned?
      result = result.assigned_to(assignees.ids) if assignees.present?
      result = result.in_bucket(buckets.ids) if buckets.present?
      result = result.tagged_with(tags.ids) if tags.present?
      result
    end
  end

  def cacheable?
    buckets.exists?
  end

  def cache_key
    ActiveSupport::Cache.expand_cache_key buckets.cache_key_with_version, super
  end
end
