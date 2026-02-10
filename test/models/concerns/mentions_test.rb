require "test_helper"
require "cgi"

class MentionsTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "don't create mentions when creating or updating drafts" do
    assert_no_difference -> { Mention.count } do
      perform_enqueued_jobs only: Mention::CreateJob do
        card = boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup, #{mention_html_for(users(:david))}?"
        card.update description: "Any thoughts here #{mention_html_for(users(:jz))}"
      end
    end
  end

  test "create mentions from plain text mentions when publishing cards" do
    perform_enqueued_jobs only: Mention::CreateJob do
      card = assert_no_difference -> { Mention.count } do
        boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup, #{mention_html_for(users(:david))}?"
      end

      card = Card.find(card.id)

      assert_difference -> { Mention.count }, +1 do
        card.publish
      end
    end
  end

  test "create mentions from rich text mentions when publishing cards" do
    perform_enqueued_jobs only: Mention::CreateJob do
      card = assert_no_difference -> { Mention.count } do
        boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup, #{mention_html_for(users(:david))}?"
      end

      card = Card.find(card.id)

      assert_difference -> { Mention.count }, +1 do
        card.published!
      end
    end
  end

  test "don't create repeated mentions when updating cards" do
    perform_enqueued_jobs only: Mention::CreateJob do
      card = boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup, #{mention_html_for(users(:david))}?"

      assert_difference -> { Mention.count }, +1 do
        card.published!
      end

      assert_no_difference -> { Mention.count } do
        card.update description: "Any thoughts here #{mention_html_for(users(:david))}"
      end

      assert_no_difference -> { Mention.count } do
        card.update description: "Any thoughts here #{mention_html_for(users(:jz))}"
      end

      assert_includes card.reload.mentionees, users(:jz)
      assert_not_includes card.mentionees, users(:david)
    end
  end

  test "tracks mentioned and unmentioned events when card mentions change" do
    perform_enqueued_jobs only: Mention::CreateJob do
      card = boards(:writebook).cards.create!(title: "Mention event", description: "Hello #{mention_html_for(users(:david))}")

      assert_difference -> { card.events.where(action: "card_mentioned").count }, +1 do
        card.publish
      end

      mentioned_event = card.events.where(action: "card_mentioned").last
      assert_equal [ users(:david) ], mentioned_event.mentionees

      assert_difference -> { card.events.where(action: "card_unmentioned").count }, +1 do
        card.update!(description: "No mentions now")
      end

      unmentioned_event = card.events.where(action: "card_unmentioned").last
      assert_equal [ users(:david) ], unmentioned_event.mentionees
    end
  end

  test "create mentions from plain text mentions when posting comments" do
    perform_enqueued_jobs only: Mention::CreateJob do
      card = boards(:writebook).cards.create title: "Cleanup", description: "Some initial content", status: :published

      assert_difference -> { Mention.count }, +1 do
        card.comments.create!(body: "Great work on this #{mention_html_for(users(:david))}!")
      end
    end
  end

  test "create mention and notification from plain @handle in card description" do
    mentionee = users(:kevin)

    assert_difference -> { Mention.count }, +1 do
      assert_difference -> { mentionee.notifications.count }, +1 do
        perform_enqueued_jobs do
          boards(:writebook).cards.create!(
            title: "Plain handle mention",
            status: :published,
            description: "Please check this, @#{mentionee.mention_handle}"
          )
        end
      end
    end
  end

  test "create mention notifications for each mentionee in a single comment" do
    card = cards(:logo)
    mentionee_one = users(:kevin)
    mentionee_two = users(:jz)
    markdown = "Ping [@#{mentionee_one.name}](#{mentionee_one.mention_handle}) and [@#{mentionee_two.name}](#{mentionee_two.mention_handle})"

    assert_difference -> { Mention.count }, +2 do
      assert_difference -> { Notification.where(source_type: "Mention").count }, +2 do
        perform_enqueued_jobs do
          card.comments.create!(body: markdown)
        end
      end
    end

    assert_equal [ mentionee_one.id, mentionee_two.id ].sort, card.comments.last.mentions.pluck(:mentionee_id).sort
    mention_notifications = Notification.where(source_type: "Mention").order(:created_at).last(2)
    assert_equal [ mentionee_one.id, mentionee_two.id ].sort, mention_notifications.map(&:user_id).sort
  end

  # 产品语义：支持跨账号/看板提及，被提及人无看板权限时仍会创建 Mention，以便其通过通知访问该卡片
  test "mentioning user without board access still creates mention so they can view the card" do
    boards(:writebook).update! all_access: false
    boards(:writebook).accesses.revoke_from(users(:david))
    david = users(:david)
    assert_not boards(:writebook).accessible_to?(david), "david should not have board access"

    card = nil
    assert_difference -> { Mention.count }, 1 do
      perform_enqueued_jobs only: Mention::CreateJob do
        card = boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup, #{mention_html_for(david)}?"
        card.published!
      end
    end
    card = Card.find_by(title: "Cleanup")
    assert card.mentionees.include?(david), "Mention should be created for user without board access"
    assert david.cards_accessible_via_mention(boards(:writebook).account).exists?(id: card.id), "Mentioned user should be able to view the card"
  end

  test "mentionees are added as watchers of the card" do
    perform_enqueued_jobs only: Mention::CreateJob do
      card = boards(:writebook).cards.create title: "Cleanup", description: "Did you finish up with the cleanup #{mention_html_for(users(:kevin))}?"
      card.published!
      assert card.watchers.include?(users(:kevin))
    end
  end

  test "normalizes action-text-attachment gid to sgid on save (mention-style submission)" do
    user = users(:kevin)
    gid = user.to_global_id.to_s
    html = "<p>Hello <action-text-attachment content-type=\"application/vnd.actiontext.mention\" gid=\"#{gid}\">☒</action-text-attachment></p>"
    card = boards(:writebook).cards.create! title: "Mention normalizer", description: html
    card.reload
    body = card.description.body.to_s
    assert_includes body, "sgid=", "Stored body should contain sgid after normalizer"
    # mention 节点保留 gid 作为渲染回退，避免 sgid 无效时显示「未知用户」
    assert_includes body, "gid=", "Mention nodes should keep gid for render fallback"
  end

  test "infers mention user from escaped content image and fills gid/sgid" do
    user = users(:kevin)
    escaped_content = CGI.escapeHTML(%(<img src="/users/#{user.id}/avatar" />))
    html = <<~HTML.squish
      <p>
        Hello
        <action-text-attachment content-type="application/vnd.actiontext.mention" content="#{escaped_content}">☒</action-text-attachment>
      </p>
    HTML

    card = boards(:writebook).cards.create!(title: "Mention infer from content", description: html)
    card.reload
    body = card.description.body.to_s

    assert_includes body, "gid=\"#{user.to_global_id}\""
    assert_includes body, "sgid="
    assert_includes body, "@#{user.first_name.downcase}"
  end

  test "fills unknown user label when mention cannot be resolved" do
    html = <<~HTML.squish
      <p>
        Hello
        <action-text-attachment content-type="application/vnd.actiontext.mention" content="not-a-user">☒</action-text-attachment>
      </p>
    HTML

    card = boards(:writebook).cards.create!(title: "Mention unknown fallback", description: html)
    card.reload
    body = card.description.body.to_s

    assert_includes body, I18n.t("users.missing_attachable_label")
    assert_no_match(/content=/, body)
  end

  # mention 解析统一走 MentionResolver：节点仅有 gid 或 sgid 失效时，仍能正确创建 Mention（不依赖 attachment.attachable）
  test "creates mention when node has valid gid but invalid sgid" do
    user = users(:kevin)
    gid = user.to_global_id.to_s
    html = "<p>Hey <action-text-attachment content-type=\"application/vnd.actiontext.mention\" sgid=\"invalid-sgid\" gid=\"#{gid}\">@kevin</action-text-attachment></p>"

    perform_enqueued_jobs only: Mention::CreateJob do
      card = boards(:writebook).cards.create!(title: "Gid fallback", description: html)
      card.published!
    end

    card = Card.find_by(title: "Gid fallback")
    assert card.mentionees.include?(user), "Mentionee should be resolved via MentionResolver (gid) and create Mention"
  end

  test "creates mention when node has gid only (no sgid)" do
    user = users(:david)
    gid = user.to_global_id.to_s
    html = "<p>Hi <action-text-attachment content-type=\"application/vnd.actiontext.mention\" gid=\"#{gid}\">@david</action-text-attachment></p>"

    perform_enqueued_jobs only: Mention::CreateJob do
      card = boards(:writebook).cards.create!(title: "Gid only mention", description: html)
      card.published!
    end

    card = Card.find_by(title: "Gid only mention")
    assert card.mentionees.include?(user), "Mentionee should be resolved from gid-only node via MentionResolver"
  end

  test "creates mention for comment when node has valid gid but invalid sgid" do
    card = cards(:logo)
    user = users(:kevin)
    gid = user.to_global_id.to_s
    html = "<p>Thanks <action-text-attachment content-type=\"application/vnd.actiontext.mention\" sgid=\"invalid\" gid=\"#{gid}\">@kevin</action-text-attachment></p>"

    perform_enqueued_jobs only: Mention::CreateJob do
      card.comments.create!(body: html)
    end

    comment = card.comments.last
    assert comment.mentionees.include?(user), "Comment mentionee should be resolved via MentionResolver (gid fallback)"
  end

  test "mentionable_content keeps mention text when sgid is invalid but gid is valid" do
    card = cards(:logo)
    user = users(:kevin)
    gid = user.to_global_id.to_s
    html = "<p>Hi <action-text-attachment content-type=\"application/vnd.actiontext.mention\" sgid=\"invalid\" gid=\"#{gid}\">@kevin</action-text-attachment></p>"

    comment = card.comments.create!(body: html)
    content = comment.mentionable_content

    assert_includes content, user.attachable_plain_text_representation
    assert_no_match(/#{Regexp.escape(I18n.t("users.missing_attachable_label"))}/, content)
  end

  private
    def mention_html_for(user)
      ActionText::Attachment.from_attachable(user).to_html
    end
end
