require "test_helper"

class NotificationsHelperTest < ActionView::TestCase
  include NotificationsHelper
  include RichTextHelper

  test "mention notification body resolves mention text when sgid invalid but gid valid" do
    card = cards(:logo)
    user = users(:kevin)
    html = "<p>Hi <action-text-attachment content-type=\"application/vnd.actiontext.mention\" sgid=\"invalid\" gid=\"#{user.to_global_id}\">@kevin</action-text-attachment></p>"
    comment = card.comments.create!(body: html, creator: users(:david))
    mention = Struct.new(:source).new(comment)

    body = mention_notification_body(mention, length: 200)

    assert_includes body, user.attachable_plain_text_representation
    assert_no_match(/#{Regexp.escape(I18n.t("users.missing_attachable_label"))}/, body)
  end

  test "mention notification body prefers markdown display text for unresolved handles" do
    card = cards(:logo)
    comment = card.comments.create!(body: "[@小明](user2)", creator: users(:david))
    mention = Struct.new(:source).new(comment)

    body = mention_notification_body(mention, length: 200)

    assert_includes body, "@小明"
    assert_no_match(/#{Regexp.escape(I18n.t("users.missing_attachable_label"))}/, body)
  end

  test "mention notification title falls back to unscoped lookup by mentioner_id" do
    user = users(:kevin)
    mention = Struct.new(:mentioner, :mentioner_id).new(nil, user.id)

    title = mention_notification_title(mention)

    assert_equal I18n.t("notifications.mention_mentioned_you", name: user.name), title
  end

  test "mention notification title falls back to source creator name" do
    creator = users(:jz)
    source = Struct.new(:creator).new(creator)
    mention = Struct.new(:mentioner, :mentioner_id, :source).new(nil, SecureRandom.uuid, source)

    title = mention_notification_title(mention)

    assert_equal I18n.t("notifications.mention_mentioned_you", name: creator.name), title
  end

  test "comment notification body keeps mention display name instead of unknown user fallback" do
    card = cards(:logo)
    comment = card.comments.create!(body: "[@小明](user2)", creator: users(:david))
    event = Struct.new(:eventable).new(comment)

    body = send(:comment_notification_body, event)

    assert_includes body, "@小明"
    assert_no_match(/#{Regexp.escape(I18n.t("users.missing_attachable_label"))}/, body)
  end
end
