module Bucket::View::Assignees
  extend ActiveSupport::Concern

  included do
    store_accessor :filters, :assignee_ids
  end

  private
    def assignee_names
      assignees.map &:name
    end

    def assignees
      @assignees ||= account.users.where id: assignee_ids
    end
end
