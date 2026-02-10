# frozen_string_literal: true

require "test_helper"

class HtmlToMarkdownTest < ActiveSupport::TestCase
  setup do
    @user = users(:kevin)
  end

  test "convert returns empty string for blank input" do
    assert_equal "", HtmlToMarkdown.convert("")
    assert_equal "", HtmlToMarkdown.convert(nil)
  end

  test "convert converts mention action-text-attachment to token with handle when user resolvable" do
    sgid = @user.attachable_sgid
    html = "<p>Hi <action-text-attachment content-type=\"application/vnd.actiontext.mention\" sgid=\"#{sgid}\">#{@user.name}</action-text-attachment>!</p>"
    md = HtmlToMarkdown.convert(html)
    assert_includes md, "[@#{@user.name}](#{@user.mention_handle})"
  end

  test "convert converts mention to display text when user not resolvable" do
    html = "<p>Hi <action-text-attachment content-type=\"application/vnd.actiontext.mention\" sgid=\"some-sgid\">Unknown</action-text-attachment>!</p>"
    md = HtmlToMarkdown.convert(html)
    assert_includes md, "Unknown"
  end

  test "convert converts blob image node with data attributes to token" do
    html = "<p>See <action-text-attachment sgid=\"abc123\" data-filename=\"photo.jpg\" data-blob-type=\"image\">photo.jpg</action-text-attachment></p>"
    md = HtmlToMarkdown.convert(html)
    assert_includes md, "![photo.jpg](blob-sgid:abc123)"
  end

  test "convert converts blob file node to token" do
    html = "<p>Get <action-text-attachment sgid=\"xyz789\" data-filename=\"doc.pdf\" data-blob-type=\"file\">doc.pdf</action-text-attachment></p>"
    md = HtmlToMarkdown.convert(html)
    assert_includes md, "[doc.pdf](blob-sgid:xyz789)"
  end

  test "convert returns [attachment] for attachment node without sgid" do
    html = "<p><action-text-attachment>unknown</action-text-attachment></p>"
    md = HtmlToMarkdown.convert(html)
    assert_includes md, "[attachment]"
  end

  test "roundtrip mention token survives to_html and convert" do
    handle = @user.mention_handle
    markdown = "Hello [@#{@user.name}](#{handle})"
    html = MarkdownRenderer.to_html(markdown)
    back = HtmlToMarkdown.convert(html)
    assert_includes back, "[@#{@user.name}](#{handle})"
  end

  test "roundtrip blob image token survives to_html and convert" do
    markdown = "![photo.jpg](blob-sgid:blob-signed-id-here)"
    html = MarkdownRenderer.to_html(markdown)
    back = HtmlToMarkdown.convert(html)
    assert_includes back, "![photo.jpg](blob-sgid:blob-signed-id-here)"
  end

  test "roundtrip blob file token survives to_html and convert" do
    markdown = "[doc.pdf](blob-sgid:file-signed-id)"
    html = MarkdownRenderer.to_html(markdown)
    back = HtmlToMarkdown.convert(html)
    assert_includes back, "[doc.pdf](blob-sgid:file-signed-id)"
  end

  test "convert infers blob info from active storage signed_id" do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_fixture("moon.jpg").open,
      filename: "moon.jpg",
      content_type: "image/jpeg"
    )
    html = "<p><action-text-attachment sgid=\"#{blob.signed_id}\">moon.jpg</action-text-attachment></p>"

    md = HtmlToMarkdown.convert(html)

    assert_includes md, "![moon.jpg](blob-sgid:#{blob.signed_id})"
  end
end
