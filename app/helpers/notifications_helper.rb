module NotificationsHelper
  def event_notification_title(event)
    case event_notification_action(event)
    when "comment_created" then I18n.t("notifications.re_prefix", title: card_notification_title(event.eventable.card))
    else card_notification_title(event.eventable)
    end
  end

  def reaction_notification_body(reaction)
    creator = reaction.reacter.name
    if reaction.reactable.is_a?(Comment)
      I18n.t("notifications.reacted_to_your_comment", creator: creator, content: reaction.content)
    else
      I18n.t("notifications.reacted_to_your_card", creator: creator, content: reaction.content)
    end
  end

  def event_notification_body(event)
    creator = event.creator.name

    case event_notification_action(event)
    when "card_assigned" then event.assignees.none? ? I18n.t("notifications.assigned_to_self") : I18n.t("notifications.assigned_to", assignees: event.assignees.pluck(:name).to_sentence)
    when "card_unassigned" then I18n.t("notifications.unassigned_by", creator: creator)
    when "card_published" then I18n.t("notifications.added_by", creator: creator)
    when "card_closed" then I18n.t("notifications.moved_to_done_by", creator: creator)
    when "card_reopened" then I18n.t("notifications.reopened_by", creator: creator)
    when "card_postponed" then I18n.t("notifications.moved_to_not_now_by", creator: creator)
    when "card_auto_postponed" then I18n.t("notifications.moved_to_not_now_inactivity")
    when "card_title_changed" then I18n.t("notifications.renamed_by", creator: creator)
    when "card_board_changed" then I18n.t("notifications.moved_by", creator: creator)
    when "card_triaged" then I18n.t("notifications.moved_to_column_by", column: event.particulars.dig("particulars", "column"), creator: creator)
    when "card_sent_back_to_triage" then I18n.t("notifications.moved_back_to_maybe_by", creator: creator)
    when "comment_created" then comment_notification_body(event)
    else creator
    end
  end

  def mention_notification_title(mention)
    I18n.t("notifications.mention_mentioned_you", name: mention_notification_creator_name(mention))
  end

  def mention_notification_body(mention, length: 200)
    mention_source_plain_text(mention.source).truncate(length)
  end

  def notification_tag(notification, &)
    tag.div id: dom_id(notification), class: "tray__item tray__item--notification", data: {
      navigable_list_target: "item",
      notifications_tray_target: "notification",
      card_id: notification.card.id,
      timestamp: notification.created_at.to_i
    } do
      link_to(notification_target_url(notification),
        class: [ "card card--notification", { "card--closed": notification.card.closed? }, { "unread": !notification.read? } ],
        data: { turbo_frame: "_top", badge_target: "unread", action: "badge#update dialog#close" },
        style: { "--card-color:": notification.card.color },
        &)
    end
  end

  # 使用通知所属账号的 script_name 生成链接，避免跨账号时 404
  def notification_target_url(notification)
    user_board_card_path(notification.card.board.url_user, notification.card.board, notification.card)
  end

  def notification_toggle_read_button(notification, url:)
    if notification.read?
      button_to url,
          method: :delete,
          class: "card__notification-unread-indicator btn btn--circle borderless",
          title: t("notifications.mark_as_unread"),
          data: { action: "form#submit:prevent:stop badge#update:stop", form_target: "submit" },
          form: { data: { controller: "form" } } do
        concat(icon_tag("unseen"))
      end
    else
      button_to url,
          class: "card__notification-unread-indicator btn btn--circle borderless",
          title: t("notifications.mark_as_read"),
          data: { action: "form#submit:prevent:stop badge#update:stop", form_target: "submit" },
          form: { data: { controller: "form" } } do
        concat(icon_tag("remove"))
        concat(tag.span("1", class: "badge-count", data: { group_count: "" }))
      end
    end
  end

  def notifications_next_page_link(page)
    unless @page.last?
      tag.div id: "next_page", data: { controller: "fetch-on-visible", fetch_on_visible_url_value: notifications_path(page: @page.next_param) }
    end
  end

  def bundle_email_frequency_options_for(settings)
    options_for_select([
      [ t("notifications.bundle_frequency.never"), "never" ],
      [ t("notifications.bundle_frequency.every_minute"), "every_minute" ],
      [ t("notifications.bundle_frequency.every_few_hours"), "every_few_hours" ],
      [ t("notifications.bundle_frequency.daily"), "daily" ],
      [ t("notifications.bundle_frequency.weekly"), "weekly" ]
    ], settings.bundle_email_frequency)
  end

  private
    def mention_notification_creator_name(mention)
      source_creator_name = if mention.respond_to?(:source) && mention.source.respond_to?(:creator)
        mention.source.creator&.name
      end

      mention.mentioner&.name.presence ||
        source_creator_name.presence ||
        User.unscoped.find_by(id: mention.mentioner_id)&.name ||
        I18n.t("users.missing_attachable_label", default: "Unknown user")
    end

    def mention_source_plain_text(source)
      MentionSourceExcerpt.plain_text(source)
    end

    def event_notification_action(event)
      if event.action.card_published? && event.eventable.assigned_to?(event.creator)
        "card_assigned"
      else
        event.action
      end
    end

    def comment_notification_body(event)
      comment = event.eventable
      MentionSourceExcerpt.plain_text(comment).truncate(200)
    end

    def card_notification_title(card)
      card.title.presence || I18n.t("notifications.card_title", number: card.number)
    end
end
