# 卡片/评论的 reaction 通知：通知归属者（卡片 creator 或评论 creator），排除操作者本人
class Notifier::ReactionNotifier < Notifier
  alias reaction source

  private
    def creator
      reaction.reacter
    end

    def recipients
      owner = reactable_owner
      return [] if owner.blank?
      recipients_for(owner).excluding(creator).uniq
    end

    def recipients_for(owner)
      return Array(owner) unless reaction.reactable.is_a?(Comment)
      return Array(owner) if owner.identity.blank?

      # Cross-account comment participants may not have a user in the card account.
      # Fan out to all active users under the same identity so the real person
      # receives the reaction notification in their own account context as well.
      owner.identity.users.active.to_a.presence || Array(owner)
    end

    def reactable_owner
      case reaction.reactable
      when Card
        reaction.reactable.creator
      when Comment
        reaction.reactable.creator
      else
        nil
      end
    end
end
