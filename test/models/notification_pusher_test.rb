require "test_helper"

class NotificationPusherTest < ActiveSupport::TestCase
  setup do
    @user = users(:david)
    @notification = @user.notifications.create!(
      source: events(:logo_published),
      creator: users(:jason)
    )
    @pusher = NotificationPusher.new(@notification)

    @user.push_subscriptions.create!(
      endpoint: "https://fcm.googleapis.com/fcm/send/test123",
      p256dh_key: "test_key",
      auth_key: "test_auth"
    )
  end

  test "push does not send notifications for cancelled accounts" do
    @user.account.cancel(initiated_by: @user)

    result = @pusher.push

    assert_nil result, "Should not push notifications for cancelled accounts"
  end

  test "push sends notifications for active accounts with subscriptions" do
    result = @pusher.push

    assert_not_nil result, "Should push notifications for active accounts with subscriptions"
  end

  test "build mention payload resolves title and body without unknown fallback" do
    mentioner = users(:kevin)
    mentionee = users(:david)
    card = cards(:logo)
    mention_html = "<action-text-attachment content-type=\"application/vnd.actiontext.mention\" sgid=\"invalid\" gid=\"#{mentioner.to_global_id}\">@kevin</action-text-attachment>"
    comment = card.comments.create!(body: "<p>Hi #{mention_html}</p>", creator: mentioner)
    mention = Mention.create!(source: comment, mentioner: mentioner, mentionee: mentionee, account: mentionee.account)
    notification = mentionee.notifications.create!(source: mention, creator: mentioner, account: mentionee.account)

    payload = NotificationPusher.new(notification).send(:build_payload)

    assert_equal I18n.t("notifications.mention_mentioned_you", name: mentioner.name), payload[:title]
    assert_includes payload[:body], mentioner.attachable_plain_text_representation
    assert_no_match(/#{Regexp.escape(I18n.t("users.missing_attachable_label"))}/, payload[:body])
  end

  test "build mention payload uses markdown display text for unresolved handles" do
    mentioner = users(:kevin)
    mentionee = users(:david)
    card = cards(:logo)
    comment = card.comments.create!(body: "[@小明](user2)", creator: mentioner)
    mention = Mention.create!(source: comment, mentioner: mentioner, mentionee: mentionee, account: mentionee.account)
    notification = mentionee.notifications.create!(source: mention, creator: mentioner, account: mentionee.account)

    payload = NotificationPusher.new(notification).send(:build_payload)

    assert_includes payload[:body], "@小明"
    assert_no_match(/#{Regexp.escape(I18n.t("users.missing_attachable_label"))}/, payload[:body])
  end

  test "build event payload keeps comment mention display name instead of unknown fallback" do
    creator = users(:david)
    receiver = users(:kevin)
    comment = cards(:logo).comments.create!(body: "[@小明](user2)", creator: creator)
    event = comment.events.last
    notification = receiver.notifications.create!(source: event, creator: creator, account: receiver.account)

    payload = NotificationPusher.new(notification).send(:build_payload)

    assert_includes payload[:body], "@小明"
    assert_no_match(/#{Regexp.escape(I18n.t("users.missing_attachable_label"))}/, payload[:body])
  end

  test "mentioner_name_for_notification falls back to unscoped lookup" do
    mentioner = users(:kevin)
    mention = Struct.new(:mentioner, :mentioner_id).new(nil, mentioner.id)

    name = @pusher.send(:mentioner_name_for_notification, mention)

    assert_equal mentioner.name, name
  end

  test "mentioner_name_for_notification falls back to source creator name" do
    creator = users(:jz)
    source = Struct.new(:creator).new(creator)
    mention = Struct.new(:mentioner, :mentioner_id, :source).new(nil, SecureRandom.uuid, source)

    name = @pusher.send(:mentioner_name_for_notification, mention)

    assert_equal creator.name, name
  end
end
