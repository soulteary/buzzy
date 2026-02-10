module Event::Particulars
  extend ActiveSupport::Concern

  included do
    store_accessor :particulars, :assignee_ids
    store_accessor :particulars, :mentionee_ids
  end

  def assignees
    @assignees ||= User.where id: assignee_ids
  end

  def mentionees
    @mentionees ||= User.where id: mentionee_ids
  end
end
