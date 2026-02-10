# frozen_string_literal: true

# Converts ActionText HTML to Markdown, preserving mention tokens and basic structure.
# Used by the one-off migration to backfill body_markdown from body (HTML).
# Mention nodes become [@display](user_id) when user is resolvable; otherwise display text only.
module HtmlToMarkdown
  MENTION_CONTENT_TYPE = "application/vnd.actiontext.mention"

  class << self
    def convert(html)
      return "" if html.blank?

      fragment = Nokogiri::HTML.fragment(html)
      parts = []
      fragment.children.each { |node| parts << node_to_markdown(node) }
      parts.join("\n\n").strip
    end

    private

    def node_to_markdown(node)
      case node
      when Nokogiri::XML::Text
        node.text
      when Nokogiri::XML::Element
        element_to_markdown(node)
      else
        ""
      end
    end

    def element_to_markdown(node)
      case node.name
      when "action-text-attachment"
        attachment_to_markdown(node)
      when "p"
        inline_children(node) + "\n\n"
      when "br"
        "\n"
      when "strong", "b"
        "**#{inline_children(node)}**"
      when "em", "i"
        "*#{inline_children(node)}*"
      when "a"
        href = node["href"].to_s
        text = inline_children(node)
        href.present? ? "[#{text}](#{href})" : text
      when "code"
        "`#{node.text}`"
      when "pre"
        code = node.at_css("code")
        lang = code&.[]("class")&.slice(/\blanguage-(\w+)/, 1) || ""
        "```#{lang}\n#{code ? code.text : node.text}```\n\n"
      when "blockquote"
        block_children(node).each_line.map { |l| "> #{l}" }.join.chomp + "\n\n"
      when "ul"
        block_children(node).each_line.map { |l| "- #{l.strip}" }.join("\n") + "\n\n"
      when "ol"
        block_children(node).each_line.each_with_index.map { |l, i| "#{i + 1}. #{l.strip}" }.join("\n") + "\n\n"
      when "li"
        inline_children(node) + "\n"
      when "h1" then "# #{inline_children(node)}\n\n"
      when "h2" then "## #{inline_children(node)}\n\n"
      when "h3" then "### #{inline_children(node)}\n\n"
      when "h4" then "#### #{inline_children(node)}\n\n"
      when "h5" then "##### #{inline_children(node)}\n\n"
      when "h6" then "###### #{inline_children(node)}\n\n"
      when "hr" then "---\n\n"
      when "div"
        block_children(node) + "\n\n"
      else
        block_children(node)
      end
    end

    def attachment_to_markdown(node)
      content_type = (node["content-type"] || "").to_s.downcase
      if content_type.include?("mention")
        display = (node.text || "").strip.presence || "@"
        user = ActionText::MentionResolver.resolve_user(node)
        if user && user.respond_to?(:mention_handle) && user.mention_handle.present?
          "[@#{display}](#{user.mention_handle})"
        else
          display
        end
      else
        sgid = node["sgid"].to_s.presence
        if sgid.blank?
          "[attachment]"
        else
          filename = node["data-filename"].to_s.presence || (node.text || "").strip.presence
          blob_type = (node["data-blob-type"] || "").to_s.downcase
          if filename.blank? || blob_type.blank?
            blob_info = resolve_blob_sgid(sgid)
            filename = blob_info[:filename] if filename.blank? && blob_info
            blob_type = blob_info[:type].to_s if blob_type.blank? && blob_info
          end
          filename = filename.presence || "file"
          blob_type = blob_type.presence || "file"
          if blob_type == "image"
            "![#{filename}](blob-sgid:#{sgid})"
          else
            "[#{filename}](blob-sgid:#{sgid})"
          end
        end
      end
    end

    def resolve_blob_sgid(sgid)
      parsed = SignedGlobalID.parse(sgid, for: ActionText::Attachable::LOCATOR_NAME)
      blob =
        if parsed&.model_class == ActiveStorage::Blob
          parsed.find
        else
          ActiveStorage::Blob.find_signed(sgid)
        end
      return nil unless blob

      image = blob.content_type.to_s.start_with?("image/")
      { filename: blob.filename.to_s.presence || "file", type: image ? :image : :file }
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound, GlobalID::IdentificationError
      nil
    end

    def inline_children(node)
      node.children.map { |c| node_to_markdown(c) }.join
    end

    def block_children(node)
      node.children.map { |c| node_to_markdown(c) }.join
    end
  end
end
