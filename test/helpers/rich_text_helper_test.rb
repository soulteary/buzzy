require "test_helper"

class RichTextHelperTest < ActionView::TestCase
  include RichTextHelper

  test "rich_text_with_attachments renders users attachable for mention user" do
    card = cards(:logo)
    mention_html = ActionText::Attachment.from_attachable(users(:kevin)).to_html
    card.update!(description: "<p>Hello #{mention_html}</p>")

    rendered = rich_text_with_attachments(card.description)

    assert_includes rendered, "mention--inline"
    assert_includes rendered, users(:kevin).first_name
    assert_includes rendered, "href=", "Mention should render as clickable link"
    assert_match %r{/users/#{users(:kevin).id}/profile}, rendered, "Mention link should point to user profile"
  end

  test "rich_text_with_attachments renders missing attachable for unknown mention" do
    card = cards(:logo)
    card.update!(
      description: <<~HTML.squish
        <p>
          Hello
          <action-text-attachment content-type="application/vnd.actiontext.mention" sgid="invalid-sgid" gid="gid://buzzy/User/non-existent">x</action-text-attachment>
        </p>
      HTML
    )

    rendered = rich_text_with_attachments(card.description)

    assert_includes rendered, "mention--missing"
    assert_includes rendered, I18n.t("users.missing_attachable_label")
  end

  test "mention_attachment? falls back to resolver for legacy gid-only mention nodes" do
    attachment = Struct.new(:node).new({ "gid" => users(:kevin).to_global_id.to_s })

    assert send(:mention_attachment?, attachment)
  end

  test "mention_attachment? returns false for non-user gid nodes without mention content-type" do
    attachment = Struct.new(:node).new({ "gid" => tags(:web).to_global_id.to_s })

    assert_not send(:mention_attachment?, attachment)
  end

  test "resolve_attachable_from_gid returns attachable for valid gid" do
    node = { "gid" => users(:kevin).to_global_id.to_s }

    assert_equal users(:kevin), send(:resolve_attachable_from_gid, node)
  end

  test "resolve_attachable_from_gid returns nil for invalid gid" do
    node = { "gid" => "invalid-gid" }

    assert_nil send(:resolve_attachable_from_gid, node)
  end

  test "resolve_attachable_from_sgid returns blob for active storage signed_id" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("moon.jpg").open,
      filename: "moon.jpg",
      content_type: "image/jpeg"
    )

    assert_equal blob, send(:resolve_attachable_from_sgid, { "sgid" => blob.signed_id })
  end

  test "render_remote_url_attachment renders image preview figure" do
    node = {
      "url" => "https://example.com/pic.jpg",
      "content-type" => "image/jpeg",
      "caption" => "A picture",
      "filename" => "pic.jpg"
    }

    html = send(:render_remote_url_attachment, node).to_s

    assert_includes html, "attachment--preview"
    assert_includes html, "img"
    assert_includes html, "A picture"
  end

  test "render_remote_url_attachment renders video preview figure" do
    node = {
      "url" => "https://example.com/video.mp4",
      "content-type" => "video/mp4",
      "caption" => "A video"
    }

    html = send(:render_remote_url_attachment, node).to_s

    assert_includes html, "attachment--video"
    assert_includes html, "<video"
    assert_includes html, "A video"
  end

  test "rich_text_with_attachments renders markdown video link as video with caption" do
    card = cards(:logo)
    card.update!(description: "[打开 Buzzy 菜单（视频）](/video/open-menu.mp4)")

    rendered = rich_text_with_attachments(card.description)

    assert_includes rendered, "attachment--video"
    assert_includes rendered, "<video"
    assert_includes rendered, "打开 Buzzy 菜单（视频）"
    assert_includes rendered, "/video/open-menu.mp4"
  end

  test "attachment_unavailable_placeholder renders expected marker" do
    html = send(:attachment_unavailable_placeholder).to_s

    assert_includes html, "attachment-placeholder"
    assert_includes html, "data-attachment=\"unavailable\""
    assert_includes html, I18n.t("shared.attachment_unavailable")
  end

  test "rich_text_with_attachments renders mention via gid when sgid is invalid" do
    user = users(:kevin)
    html = "<p>Hi <action-text-attachment content-type=\"application/vnd.actiontext.mention\" sgid=\"invalid\" gid=\"#{user.to_global_id}\">@kevin</action-text-attachment></p>"
    card = cards(:logo)
    card.update!(description: html)

    rendered = rich_text_with_attachments(card.description)

    assert_includes rendered, "mention--inline"
    assert_includes rendered, user.first_name
  end

  test "users attachable partial renders missing when given non-User" do
    non_user = Struct.new(:name).new("Fake")
    rendered = render partial: "users/attachable", locals: { user: non_user }

    assert_includes rendered, "mention--missing"
    assert_includes rendered, I18n.t("users.missing_attachable_label")
  end
end
