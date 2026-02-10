module Filterable
  extend ActiveSupport::Concern

  included do
    has_and_belongs_to_many :filters

    after_update { filters.touch_all }
    before_destroy :capture_filters_for_removal
    after_commit :notify_filters_resource_removed, on: :destroy
  end

  private
    def capture_filters_for_removal
      @_filter_ids = filter_ids
      @_resource_class = self.class.name
      @_resource_id = id
    end

    def notify_filters_resource_removed
      return unless defined?(@_filter_ids) && @_filter_ids.present?
      # Lightweight stand-in so Filter::Resources#resource_removed runs outside the destroy transaction.
      resource_stub = OpenStruct.new(id: @_resource_id, class: @_resource_class.constantize)
      Filter.where(id: @_filter_ids).find_each { |f| f.resource_removed(resource_stub) }
    end
end
