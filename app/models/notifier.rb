class Notifier
  attr_reader :source

  class << self
    def for(source)
      case source
      when Event
        "Notifier::#{source.eventable.class}EventNotifier".safe_constantize&.new(source)
      when Mention
        MentionNotifier.new(source)
      when Reaction
        Notifier::ReactionNotifier.new(source)
      end
    end
  end

  def notify
    if should_notify?
      # Processing recipients in order avoids deadlocks if notifications overlap.
      recipients.sort_by(&:id).map do |recipient|
        Notification.create! user: recipient, source: source, creator: creator
      end
    end
  end

  private
    def initialize(source)
      @source = source
    end

    def should_notify?
      !creator.system?
    end

    # Expand recipients to all active users under the same identity.
    # This keeps notifications visible when one person participates across accounts.
    def users_across_identity(users)
      Array(users).compact.flat_map do |user|
        next [] unless user.is_a?(User)

        user.identity&.users&.active&.to_a.presence || [ user ]
      end.uniq(&:id)
    end
end
