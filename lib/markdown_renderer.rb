# frozen_string_literal: true
require "uri"

# Converts Markdown to HTML and replaces @mention and blob attachment tokens with
# action-text-attachment nodes so the result can be passed through the same
# attachment/sanitize pipeline as legacy HTML.
# Token formats:
#   Mention: [@display name](handle)  — handle 为邮箱前缀，如 xiaoming.zhang（来自 xiaoming.zhang@mail.com）
#   Image:   ![filename](blob-sgid:SIGNED_GLOBAL_ID)
#   File:    [filename](blob-sgid:SIGNED_GLOBAL_ID)
module MarkdownRenderer
  MENTION_CONTENT_TYPE = "application/vnd.actiontext.mention"
  # handle: 邮箱前缀（字母数字、点、下划线、连字符等）；或兼容旧格式的 user_id（数字/UUID）。排除含 : / 的 URL
  MENTION_TOKEN_REGEX = /\[@([^\]]*)\]\((\d+|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[a-zA-Z0-9._+-]+)\)/i
  USER_ID_PATTERN = /\A(?:\d+|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\z/i
  # 纯 ASCII 占位符，避免经 Redcarpet 渲染后 \u200B 被转义或下划线被当成强调导致 sub 无法匹配
  PLACEHOLDER = "BUZZY-MENTION-%d-PH"
  BLOB_IMAGE_REGEX = /!\[([^\]]*)\]\(blob-sgid:([^)]+)\)/
  BLOB_FILE_REGEX = /\[([^\]]*)\]\(blob-sgid:([^)]+)\)/
  BLOB_PLACEHOLDER = "BUZZY-BLOB-%d-PH"
  MARKDOWN_LINK_REGEX = /\[([^\]]*)\]\(([^)\s]+)\)/
  VIDEO_PLACEHOLDER = "BUZZY-VIDEO-%d-PH"
  VIDEO_CONTENT_TYPES = {
    ".mp4" => "video/mp4",
    ".webm" => "video/webm",
    ".ogv" => "video/ogg",
    ".ogg" => "video/ogg",
    ".mov" => "video/quicktime"
  }.freeze

  class << self
    def to_html(markdown)
      return "" if markdown.blank?

      text = markdown.to_s
      mentions = []
      text = text.gsub(MENTION_TOKEN_REGEX) do
        display = Regexp.last_match(1).to_s.strip.presence || "@"
        link_part = Regexp.last_match(2).to_s.strip
        placeholder = format(PLACEHOLDER, mentions.size)
        mentions << { placeholder: placeholder, display: display, handle: link_part, user_id: link_part.match?(USER_ID_PATTERN) ? link_part : nil }
        placeholder
      end

      blobs = []
      text = text.gsub(BLOB_IMAGE_REGEX) do
        filename = Regexp.last_match(1).to_s.strip.presence || "image"
        sgid = Regexp.last_match(2).to_s.strip
        placeholder = format(BLOB_PLACEHOLDER, blobs.size)
        blobs << { placeholder: placeholder, filename: filename, sgid: sgid, type: :image }
        placeholder
      end
      text = text.gsub(BLOB_FILE_REGEX) do
        filename = Regexp.last_match(1).to_s.strip.presence || "file"
        sgid = Regexp.last_match(2).to_s.strip
        placeholder = format(BLOB_PLACEHOLDER, blobs.size)
        blobs << { placeholder: placeholder, filename: filename, sgid: sgid, type: :file }
        placeholder
      end

      videos = []
      text = text.gsub(MARKDOWN_LINK_REGEX) do
        caption = Regexp.last_match(1).to_s.strip
        url = Regexp.last_match(2).to_s.strip
        next Regexp.last_match(0) unless video_link?(url)

        placeholder = format(VIDEO_PLACEHOLDER, videos.size)
        videos << {
          placeholder: placeholder,
          caption: caption.presence || video_filename_from_url(url),
          filename: video_filename_from_url(url),
          url: url,
          content_type: video_content_type_from_url(url)
        }
        placeholder
      end

      html = redcarpet.render(text)

      mentions.each do |m|
        node = { "handle" => m[:handle], "data-handle" => m[:handle], "user_id" => m[:user_id], "id" => m[:user_id] }.compact
        user = ActionText::MentionResolver.resolve_user(node)
        sgid_attr = user ? " sgid=\"#{ERB::Util.html_escape(user.attachable_sgid)}\"" : ""
        gid_attr = user ? " gid=\"#{ERB::Util.html_escape(user.to_global_id.to_s)}\"" : ""
        data_handle_attr = m[:handle].present? ? " data-handle=\"#{ERB::Util.html_escape(m[:handle])}\"" : ""
        mention_html = <<~HTML
          <action-text-attachment content-type="#{ERB::Util.html_escape(MENTION_CONTENT_TYPE)}"#{sgid_attr}#{gid_attr}#{data_handle_attr}>#{ERB::Util.html_escape(m[:display])}</action-text-attachment>
        HTML
        html = html.sub(m[:placeholder], mention_html.strip)
      end

      blobs.each do |b|
        blob_html = <<~HTML
          <action-text-attachment sgid="#{ERB::Util.html_escape(b[:sgid])}" data-filename="#{ERB::Util.html_escape(b[:filename])}" data-blob-type="#{b[:type]}">#{ERB::Util.html_escape(b[:filename])}</action-text-attachment>
        HTML
        html = html.sub(b[:placeholder], blob_html.strip)
      end

      videos.each do |v|
        video_html = <<~HTML
          <action-text-attachment url="#{ERB::Util.html_escape(v[:url])}" caption="#{ERB::Util.html_escape(v[:caption])}" content-type="#{ERB::Util.html_escape(v[:content_type])}" filename="#{ERB::Util.html_escape(v[:filename])}"></action-text-attachment>
        HTML
        html = html.sub(v[:placeholder], video_html.strip)
      end

      html
    end

    def looks_like_markdown?(string)
      return false if string.blank?
      !string.strip.start_with?("<")
    end

    private

    def redcarpet
      @redcarpet ||= begin
        renderer = Redcarpet::Render::Safe.new(hard_wrap: true)
        Redcarpet::Markdown.new(
          renderer,
          autolink: true,
          tables: true,
          fenced_code_blocks: true,
          strikethrough: true
        )
      end
    end

    def video_link?(url)
      video_content_type_from_url(url).present? && local_video_path?(url)
    end

    def video_content_type_from_url(url)
      VIDEO_CONTENT_TYPES[video_extension_from_url(url)]
    end

    def video_extension_from_url(url)
      return nil if url.blank? || url.start_with?("blob-sgid:")

      path = begin
        URI.parse(url).path
      rescue URI::InvalidURIError
        url
      end.to_s
      ext = File.extname(path).downcase
      ext.presence
    end

    def video_filename_from_url(url)
      path = begin
        URI.parse(url).path
      rescue URI::InvalidURIError
        url
      end.to_s
      filename = File.basename(path)
      filename.present? ? filename : "video.mp4"
    end

    def local_video_path?(url)
      path = begin
        URI.parse(url).path
      rescue URI::InvalidURIError
        url
      end.to_s
      path.start_with?("/video/")
    end
  end
end
