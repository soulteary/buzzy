module Notifiable
  extend ActiveSupport::Concern

  included do
    has_many :notifications, as: :source, dependent: :destroy

    after_create_commit :notify_recipients_later
  end

  def notify_recipients
    Notifier.for(self)&.notify
  end

  def notifiable_target
    self
  end

  private
    def notify_recipients_later
      # Fallback for environments where Solid Queue is configured but no worker is alive.
      # Without this, notifications can be silently enqueued and never processed.
      if should_notify_inline_due_to_unavailable_queue?
        Rails.logger.warn "[Notifiable] Queue unavailable, notifying inline for #{self.class.name}(#{id})"
        notify_recipients
      else
        NotifyRecipientsJob.perform_later self
      end
    end

    def should_notify_inline_due_to_unavailable_queue?
      return false unless Rails.configuration.active_job.queue_adapter == :solid_queue
      return false unless defined?(SolidQueue::Process)

      !SolidQueue::Process.where("last_heartbeat_at >= ?", 1.minute.ago).exists?
    rescue StandardError => e
      Rails.logger.warn "[Notifiable] Queue health check failed: #{e.class}: #{e.message}"
      false
    end
end
