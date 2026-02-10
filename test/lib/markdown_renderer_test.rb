# frozen_string_literal: true

require "test_helper"

class MarkdownRendererTest < ActiveSupport::TestCase
  setup do
    @user = users(:kevin)
  end

  test "to_html returns empty string for blank input" do
    assert_equal "", MarkdownRenderer.to_html("")
    assert_equal "", MarkdownRenderer.to_html(nil)
  end

  test "to_html converts mention token [@display](handle) to action-text-attachment" do
    handle = @user.mention_handle
    markdown = "Hello [@#{@user.name}](#{handle}) world"
    html = MarkdownRenderer.to_html(markdown)
    assert_includes html, "action-text-attachment"
    assert_includes html, "content-type=\"application/vnd.actiontext.mention\""
    assert_includes html, "sgid="
    assert_includes html, "gid=\"#{ERB::Util.html_escape(@user.to_global_id.to_s)}\""
    assert_includes html, ERB::Util.html_escape(@user.name)
  end

  test "to_html resolves mention token with user id to the exact user" do
    markdown = "Hello [@#{@user.name}](#{@user.id})"
    html = MarkdownRenderer.to_html(markdown)
    assert_includes html, "action-text-attachment"
    assert_includes html, "content-type=\"application/vnd.actiontext.mention\""
    assert_includes html, "sgid="
    assert_includes html, "gid=\"#{ERB::Util.html_escape(@user.to_global_id.to_s)}\""
  end

  test "to_html converts blob image token to action-text-attachment" do
    markdown = "See ![photo.jpg](blob-sgid:abc123)"
    html = MarkdownRenderer.to_html(markdown)
    assert_includes html, "action-text-attachment"
    assert_includes html, "sgid=\"abc123\""
    assert_includes html, "data-filename=\"photo.jpg\""
    assert_includes html, "data-blob-type=\"image\""
  end

  test "to_html converts blob file token to action-text-attachment" do
    markdown = "Download [doc.pdf](blob-sgid:xyz789)"
    html = MarkdownRenderer.to_html(markdown)
    assert_includes html, "action-text-attachment"
    assert_includes html, "sgid=\"xyz789\""
    assert_includes html, "data-filename=\"doc.pdf\""
    assert_includes html, "data-blob-type=\"file\""
  end

  test "to_html preserves regular markdown (bold, links)" do
    markdown = "**bold** and [link](https://example.com)"
    html = MarkdownRenderer.to_html(markdown)
    assert_includes html, "<strong>bold</strong>"
    assert_includes html, "<a href=\"https://example.com\">link</a>"
  end

  test "to_html converts markdown video link to action-text-attachment with caption" do
    markdown = "[打开 Buzzy 菜单（视频）](/video/open-menu.mp4)"
    html = MarkdownRenderer.to_html(markdown)

    assert_includes html, "action-text-attachment"
    assert_includes html, "url=\"/video/open-menu.mp4\""
    assert_includes html, "caption=\"打开 Buzzy 菜单（视频）\""
    assert_includes html, "content-type=\"video/mp4\""
    assert_includes html, "filename=\"open-menu.mp4\""
  end

  test "to_html keeps non-video markdown link as anchor" do
    markdown = "[文档](https://example.com/docs)"
    html = MarkdownRenderer.to_html(markdown)

    assert_includes html, "<a href=\"https://example.com/docs\">文档</a>"
    assert_not_includes html, "content-type=\"video/"
  end

  test "to_html keeps external mp4 link as anchor" do
    markdown = "[外部视频](https://cdn.example.com/video.mp4)"
    html = MarkdownRenderer.to_html(markdown)

    assert_includes html, "<a href=\"https://cdn.example.com/video.mp4\">外部视频</a>"
    assert_not_includes html, "action-text-attachment"
    assert_not_includes html, "content-type=\"video/"
  end

  test "to_html handles mention and blob tokens together" do
    markdown = "Hi [@User](#{@user.mention_handle}) see ![x.png](blob-sgid:blob1)"
    html = MarkdownRenderer.to_html(markdown)
    assert_includes html, "application/vnd.actiontext.mention"
    assert_includes html, "data-blob-type=\"image\""
  end

  test "to_html converts multiple mention tokens" do
    other_user = users(:david)
    markdown = "Hi [@#{@user.name}](#{@user.mention_handle}) and [@#{other_user.name}](#{other_user.mention_handle})"
    html = MarkdownRenderer.to_html(markdown)

    assert_equal 2, html.scan("application/vnd.actiontext.mention").size
    assert_includes html, "data-handle=\"#{@user.mention_handle}\""
    assert_includes html, "data-handle=\"#{other_user.mention_handle}\""
  end

  test "to_html does not treat [@display](https://example.com) as mention" do
    markdown = "See [@someone](https://example.com/user/1)"
    html = MarkdownRenderer.to_html(markdown)
    assert_includes html, "<a href=\"https://example.com/user/1\">@someone</a>"
    assert_not_includes html, "application/vnd.actiontext.mention"
  end

  test "looks_like_markdown? returns false for blank" do
    assert_not MarkdownRenderer.looks_like_markdown?("")
    assert_not MarkdownRenderer.looks_like_markdown?(nil)
  end

  test "looks_like_markdown? returns false for HTML" do
    assert_not MarkdownRenderer.looks_like_markdown?("<p>hello</p>")
  end

  test "looks_like_markdown? returns true for plain text" do
    assert MarkdownRenderer.looks_like_markdown?("Hello world")
    assert MarkdownRenderer.looks_like_markdown?("# Heading")
  end
end
