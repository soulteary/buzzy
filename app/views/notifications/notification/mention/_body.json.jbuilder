mention = notification.source

json.title I18n.t("notifications.mention_mentioned_you", name: mention.mentioner.first_name)
json.body mention.source.mentionable_content.truncate(200)
