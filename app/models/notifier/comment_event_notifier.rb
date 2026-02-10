class Notifier::CommentEventNotifier < Notifier
  delegate :creator, to: :source

  private
    def recipients
      return [] if source.action.in?(%w[comment_mentioned comment_unmentioned])

      excluded_user_ids = users_across_identity([ creator, *source.eventable.mentionees ]).map(&:id)
      users_across_identity([ *card.watchers, *card.assignees, card.creator ]).reject { |user| excluded_user_ids.include?(user.id) }
    end

    def card
      source.eventable.card
    end
end
