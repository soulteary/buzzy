module PushNotifiable
  extend ActiveSupport::Concern

  included do
    after_create_commit :push_notification_later
  end

  private
    def push_notification_later
      PushNotificationJob.perform_later(self)
    end
end
