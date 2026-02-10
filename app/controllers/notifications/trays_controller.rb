class Notifications::TraysController < ApplicationController
  def show
    @notifications = Current.user.notifications.preloaded.unread.ordered.limit(100)
    @notifications = @notifications.select { |n| notification_displayable?(n) }

    # Invalidate on the whole set instead of the unread set since the max updated at in the unread set
    # can stay the same when reading old notifications.
    fresh_when Current.user.notifications
  end

  private

    def notification_displayable?(notification)
      return false if notification.source.blank?
      card = notification.source.respond_to?(:card) ? notification.source.card : nil
      card.present? && card.respond_to?(:board) && card.board.present?
    rescue
      false
    end
end
