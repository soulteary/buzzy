class Notifier::CardEventNotifier < Notifier
  delegate :creator, to: :source
  delegate :board, to: :card

  private
    def recipients
      case source.action
      when "card_assigned"
        source.assignees.excluding(creator)
      when "card_mentioned", "card_unmentioned"
        []
      when "card_published"
        board.watchers.without(creator, *card.mentionees).including(*card.assignees).uniq
      when "comment_created"
        excluded_user_ids = users_across_identity([ creator, *source.eventable.mentionees ]).map(&:id)
        users_across_identity([ *card.watchers, *card.assignees, card.creator ]).reject { |user| excluded_user_ids.include?(user.id) }
      else
        board.watchers.without(creator)
      end
    end

    def card
      source.eventable
    end
end
