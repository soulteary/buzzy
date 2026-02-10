module MentionSourceExcerpt
  extend self

  MARKDOWN_MENTION_TOKEN_REGEX = /\[@([^\]]*)\]\((\d+|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[a-zA-Z0-9._+-]+)\)/i

  def plain_text(source)
    rich_text = extract_rich_text(source)
    return fallback_plain_text(source) if rich_text.blank?

    markdown = rich_text.respond_to?(:body_markdown) ? rich_text.body_markdown.to_s : ""
    if markdown.present?
      markdown_text = markdown_plain_text(markdown)
      fallback_text = fallback_plain_text(source).to_s
      preferred_plain_text(markdown_text, fallback_text)
    else
      html_plain_text(rich_text.to_s)
    end
  rescue StandardError
    fallback_plain_text(source)
  end

  private
    def extract_rich_text(source)
      if source.respond_to?(:body) && source.body.present?
        source.body
      elsif source.respond_to?(:description) && source.description.present?
        source.description
      end
    end

    def markdown_plain_text(markdown)
      normalized_markdown = markdown.gsub(MARKDOWN_MENTION_TOKEN_REGEX) do
        display = Regexp.last_match(1).to_s.strip
        display = "@" if display.blank?
        display.start_with?("@") ? display : "@#{display}"
      end

      html_plain_text(MarkdownRenderer.to_html(normalized_markdown))
    end

    def html_plain_text(html)
      fragment = Nokogiri::HTML.fragment(html.to_s)
      fragment.css("action-text-attachment").each do |node|
        replacement = attachment_replacement_text(node, fragment)
        node.replace(Nokogiri::XML::Text.new(replacement, fragment))
      end

      ActionView::Base.full_sanitizer.sanitize(fragment.to_html).to_s.squish
    end

    def attachment_replacement_text(node, fragment)
      resolved_user = ActionText::MentionResolver.resolve_user(node_to_hash(node))
      if resolved_user.present?
        return resolved_user.attachable_plain_text_representation.to_s
      end

      node.content.to_s.strip
    rescue StandardError
      node.content.to_s.strip
    end

    def node_to_hash(node)
      attrs = node.attribute_nodes.to_h { |a| [ a.name, a.value ] }
      Object.new.tap do |obj|
        obj.define_singleton_method(:[]) do |key|
          attrs[key.to_s].presence || attrs[key.to_s.to_sym]
        end
      end
    end

    def fallback_plain_text(source)
      if source.respond_to?(:mentionable_content)
        source.mentionable_content.to_s
      else
        source.to_s
      end
    end

    def preferred_plain_text(markdown_text, fallback_text)
      unknown_label = I18n.t("users.missing_attachable_label", default: "Unknown user")
      markdown_has_unknown = markdown_text.to_s.include?(unknown_label)
      fallback_has_unknown = fallback_text.to_s.include?(unknown_label)

      return fallback_text if fallback_text.present? && !fallback_has_unknown && markdown_degraded?(markdown_text)
      return markdown_text if markdown_text.present? && !markdown_has_unknown && fallback_has_unknown
      return fallback_text if fallback_text.present? && !fallback_has_unknown
      return markdown_text if markdown_text.present? && !markdown_has_unknown

      fallback_text.presence || markdown_text
    end

    def markdown_degraded?(text)
      normalized = text.to_s.squish
      normalized.blank? || normalized.match?(/(^|\s)@($|\s|[[:punct:]])/)
    end
end
