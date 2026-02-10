class NotificationPusher
  include Rails.application.routes.url_helpers
  include ExcerptHelper

  attr_reader :notification

  def initialize(notification)
    @notification = notification
  end

  def push
    return unless should_push?

    build_payload.tap do |payload|
      push_to_user(payload)
    end
  end

  private
    def should_push?
      notification.user.push_subscriptions.any? &&
        !notification.creator.system? &&
        notification.user.active? &&
        notification.account.active?
    end

    def build_payload
      case notification.source_type
      when "Event"
        build_event_payload
      when "Mention"
        build_mention_payload
      when "Reaction"
        build_reaction_payload
      else
        build_default_payload
      end
    end

    def build_event_payload
      event = notification.source
      card = event.card

      base_payload = {
        title: card_notification_title(card),
        path: card_path(card.board, card)
      }

      case event.action
      when "comment_created"
        base_payload.merge(
          title: I18n.t("notifications.re_prefix", title: base_payload[:title]),
          body: comment_notification_body(event),
          path: card_path_with_comment_anchor(event.eventable.card.board, event.eventable.card, event.eventable)
        )
      when "card_assigned"
        base_payload.merge(
          body: I18n.t("notifications.assigned_to_you_by", creator: event.creator.name)
        )
      when "card_published"
        base_payload.merge(
          body: I18n.t("notifications.added_by", creator: event.creator.name)
        )
      when "card_closed"
        base_payload.merge(
          body: card.closure ? I18n.t("notifications.moved_to_done_by", creator: event.creator.name) : I18n.t("notifications.closed_by", creator: event.creator.name)
        )
      when "card_reopened"
        base_payload.merge(
          body: I18n.t("notifications.reopened_by", creator: event.creator.name)
        )
      else
        base_payload.merge(
          body: event.creator.name
        )
      end
    end

    def build_mention_payload
      mention = notification.source
      card = mention.card

      {
        title: I18n.t("notifications.mention_mentioned_you", name: mentioner_name_for_notification(mention)),
        body: format_excerpt(mention_source_excerpt(mention), length: 200),
        path: card_path(card.board, card)
      }
    end

    def build_reaction_payload
      reaction = notification.source
      card = reaction.card
      body = if reaction.reactable.is_a?(Comment)
        I18n.t("notifications.reacted_to_your_comment", creator: reaction.reacter.name, content: reaction.content)
      else
        I18n.t("notifications.reacted_to_your_card", creator: reaction.reacter.name, content: reaction.content)
      end

      {
        title: card_notification_title(card),
        body: body,
        path: card_path(card.board, card)
      }
    end

    def build_default_payload
      {
        title: I18n.t("notifications.new_notification_title"),
        body: I18n.t("notifications.new_notification_body"),
        path: notifications_path(script_name: notification.account.slug)
      }
    end

    def push_to_user(payload)
      subscriptions = notification.user.push_subscriptions
      enqueue_payload_for_delivery(payload, subscriptions)
    end

    def enqueue_payload_for_delivery(payload, subscriptions)
      Rails.configuration.x.web_push_pool.queue(payload, subscriptions)
    end

    def card_notification_title(card)
      card.title.presence || I18n.t("notifications.card_title", number: card.number)
    end

    def comment_notification_body(event)
      MentionSourceExcerpt.plain_text(event.eventable).truncate(200)
    end

    def card_path(board, card)
      Rails.application.routes.url_helpers.user_board_card_path(board.url_user, board, card)
    end

    def card_path_with_comment_anchor(board, card, comment)
      Rails.application.routes.url_helpers.user_board_card_path(
        board.url_user,
        board,
        card,
        anchor: ActionView::RecordIdentifier.dom_id(comment)
      )
    end

    def mentioner_name_for_notification(mention)
      source_creator_name = if mention.respond_to?(:source) && mention.source.respond_to?(:creator)
        mention.source.creator&.name
      end

      mention.mentioner&.name.presence ||
        source_creator_name.presence ||
        ::User.unscoped.find_by(id: mention.mentioner_id)&.name ||
        I18n.t("users.missing_attachable_label", default: "Unknown user")
    end

    def mention_source_excerpt(mention)
      MentionSourceExcerpt.plain_text(mention.source)
    end
end
