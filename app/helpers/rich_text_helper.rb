module RichTextHelper
  include ActionText::ContentHelper

  # 渲染富文本时用 attachable 局部视图替换所有 action-text-attachment 节点。
  # 若 body 为 Markdown（含 [@display](user_id) mention token），先经 MarkdownRenderer 转 HTML 再走同一管线。
  # mention 通过 MentionResolver 从 node 解析 User（先 sgid 再 gid），不依赖 attachment.attachable。
  def rich_text_with_attachments(rich_text)
    return "" if rich_text.blank?

    raw = (rich_text.respond_to?(:body_markdown) && rich_text.body_markdown.presence) || rich_text.body.to_s
    if MarkdownRenderer.looks_like_markdown?(raw)
      html = MarkdownRenderer.to_html(raw)
      html = enrich_mention_nodes_with_gid_from_saved_body(html, rich_text) if rich_text.respond_to?(:body) && rich_text.body.present?
      render_rich_text_html(html)
    else
      content = rich_text.body.render_attachments { |attachment| render_one_attachment(attachment) }
      sanitize_action_text_content(content)
    end
  end

  # 对 Markdown 渲染后的 HTML 做 attachment 替换与 sanitize（仅 node 信息，不依赖 attachable）。
  def render_rich_text_html(html_string)
    return "" if html_string.blank?

    fragment = Nokogiri::HTML.fragment(html_string)
    fragment.css("action-text-attachment").each do |node|
      node_wrapper = node_to_hash(node)
      attachment = Struct.new(:node).new(node_wrapper)
      replacement = render_one_attachment(attachment, node_only: true)
      node.replace(Nokogiri::HTML.fragment(replacement))
    end
    sanitize_action_text_content(ActionText::Content.new(fragment.to_html))
  end

  def render_one_attachment(attachment, node_only: false)
    is_mention = mention_attachment?(attachment)
    if is_mention
      user = ActionText::MentionResolver.resolve_user(attachment.node)
      render(user ? "users/attachable" : "users/missing_attachable", user: user)
    elsif node_only
      render_non_mention_attachment_fallback(attachment)
    else
      render_non_mention_attachment(attachment)
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound, GlobalID::IdentificationError
    is_mention = mention_attachment?(attachment)
    if is_mention
      user = ActionText::MentionResolver.resolve_user(attachment.node)
      render(user ? "users/attachable" : "users/missing_attachable", user: user)
    elsif node_only
      render_non_mention_attachment_fallback(attachment)
    else
      render_non_mention_attachment_fallback(attachment)
    end
  rescue ActionView::MissingTemplate, NoMethodError
    is_mention = mention_attachment?(attachment)
    if is_mention
      user = ActionText::MentionResolver.resolve_user(attachment.node)
      render(user ? "users/attachable" : "users/missing_attachable", user: user)
    else
      render_non_mention_attachment_fallback(attachment)
    end
  end

  # Legacy: Lexxy prompt tags; unused after Markdown editor. Kept so prompts API partials (lexxy-prompt-item) stay unchanged for markdown_prompt_controller.
  def mentions_prompt(board, card: nil)
    src = card.present? ? prompts_board_users_path(board, card_id: card.id) : prompts_board_users_path(board)
    content_tag "lexxy-prompt", "", trigger: "@", src: src, name: "mention"
  end

  def global_mentions_prompt
    content_tag "lexxy-prompt", "", trigger: "@", src: prompts_users_path, name: "mention"
  end

  def tags_prompt
    content_tag "lexxy-prompt", "", trigger: "#", src: prompts_tags_path, name: "tag"
  end

  def cards_prompt
    content_tag "lexxy-prompt", "", trigger: "#", src: prompts_cards_path, name: "card", "insert-editable-text": true, "remote-filtering": true, "supports-space-in-searches": true
  end

  def code_language_picker
    content_tag "lexxy-code-language-picker"
  end

  def general_prompts(board, card: nil)
    safe_join([ mentions_prompt(board, card: card), cards_prompt, code_language_picker ])
  end

  # Renders a Markdown editor (textarea + hidden field) that submits Markdown for the given rich text attribute.
  # Use in place of form.rich_textarea when the form is backed by has_rich_text.
  # Options: :placeholder, :class (wrapper + textarea context), :data (merged onto the textarea), :required, :autofocus, :prompts_url (URL for @mention prompt), :direct_uploads_url (for attachment uploads).
  def markdown_editor_field(form, attribute, placeholder: "", required: false, autofocus: false, prompts_url: nil, direct_uploads_url: nil, **options)
    raw = form.object.public_send(attribute)
    initial_value =
      if raw.respond_to?(:body_markdown) && raw.body_markdown.present?
        raw.body_markdown.to_s
      elsif raw.respond_to?(:body)
        html = if raw.body.respond_to?(:fragment) && raw.body.fragment.present?
          raw.body.fragment.to_html
        elsif raw.body.respond_to?(:to_html)
          raw.body.to_html
        else
          raw.body.to_s
        end
        HtmlToMarkdown.convert(html)
      else
        raw.to_s
      end
    wrapper_class = options.delete(:class) || "card__description rich-text-content"
    direct_uploads_url = direct_uploads_url.presence || rails_direct_uploads_path
    render "shared/markdown_editor_field", form: form, attribute: attribute, initial_value: initial_value.to_s, placeholder: placeholder, wrapper_class: wrapper_class, required: required, autofocus: autofocus, prompts_url: prompts_url, direct_uploads_url: direct_uploads_url, **options
  end

  private
    # 展示时若用 body_markdown 转 HTML，生成的 mention 节点只有 sgid；用已保存的 body 中的 gid 补全，避免 sgid 过期或跨环境时显示「未知用户」。
    def enrich_mention_nodes_with_gid_from_saved_body(html_from_markdown, rich_text)
      saved_html = rich_text.body.respond_to?(:fragment) && rich_text.body.fragment.present? ? rich_text.body.fragment.to_html : rich_text.body.to_s
      return html_from_markdown if saved_html.blank?

      fragment = Nokogiri::HTML.fragment(saved_html)
      sgid_to_gid = {}
      fragment.css("action-text-attachment").each do |node|
        next unless node["content-type"].to_s.downcase.include?("mention")
        sgid = node["sgid"].to_s.presence
        gid = node["gid"].to_s.presence
        sgid_to_gid[sgid] = gid if sgid.present? && gid.present?
      end
      return html_from_markdown if sgid_to_gid.empty?

      display_fragment = Nokogiri::HTML.fragment(html_from_markdown)
      display_fragment.css("action-text-attachment").each do |node|
        next unless node["content-type"].to_s.downcase.include?("mention")
        sgid = node["sgid"].to_s.presence
        node["gid"] = sgid_to_gid[sgid] if sgid.present? && sgid_to_gid.key?(sgid)
      end
      display_fragment.to_html
    end
    def mention_attachment?(attachment)
      content_type = attachment.node&.[]("content-type").to_s
      return true if content_type.downcase.include?("mention")

      # Some legacy nodes may lose content-type; infer mention by resolvable User.
      ActionText::MentionResolver.resolve_user(attachment.node).present?
    end

    def render_non_mention_attachment(attachment)
      rendered = render_action_text_attachment(attachment)
      return rendered unless rendered.to_s.strip == "☒"

      render_non_mention_attachment_fallback(attachment)
    end

    def render_non_mention_attachment_fallback(attachment)
      remote_fallback = render_remote_url_attachment(attachment.node)
      return remote_fallback if remote_fallback.present?

      fallback_attachable = resolve_attachable_from_gid(attachment.node) || resolve_attachable_from_sgid(attachment.node)
      return attachment_unavailable_placeholder unless fallback_attachable.present?

      case fallback_attachable
      when ActiveStorage::Blob
        render "active_storage/blobs/blob", blob: fallback_attachable
      else
        if fallback_attachable.respond_to?(:to_attachable_partial_path)
          render fallback_attachable
        else
          attachment_unavailable_placeholder
        end
      end
    end

    def resolve_attachable_from_gid(node)
      gid_value = node&.[]("gid").to_s.presence || node&.[](:gid).to_s.presence
      return nil if gid_value.blank?

      gid = GlobalID.parse(gid_value)
      return nil unless gid

      gid.find
    rescue GlobalID::IdentificationError, ActiveRecord::RecordNotFound, URI::InvalidURIError
      nil
    end

    def resolve_attachable_from_sgid(node)
      sgid_value = node&.[]("sgid").to_s.presence || node&.[](:sgid).to_s.presence
      return nil if sgid_value.blank?

      parsed = SignedGlobalID.parse(sgid_value, for: ActionText::Attachable::LOCATOR_NAME)
      return parsed.find if parsed

      # DirectUpload gives ActiveStorage blob signed_id, not ActionText attachable sgid.
      ActiveStorage::Blob.find_signed(sgid_value)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound, GlobalID::IdentificationError
      nil
    end

    def render_remote_url_attachment(node)
      url = node&.[]("url").to_s.presence || node&.[](:url).to_s.presence
      content_type = node&.[]("content-type").to_s.presence || node&.[](:'content-type').to_s.presence
      caption = node&.[]("caption").to_s.presence || node&.[](:caption).to_s.presence
      filename = node&.[]("filename").to_s.presence || node&.[](:filename).to_s.presence
      return nil if url.blank?

      if content_type.to_s.start_with?("video/")
        content_tag(:figure, class: "attachment attachment--preview attachment--video") do
          video_tag = tag.video(controls: true) do
            tag.source(src: url, type: content_type.presence || "video/mp4")
          end
          caption_tag = caption.present? ? content_tag(:figcaption, caption, class: "attachment__caption") : "".html_safe
          video_tag + caption_tag
        end
      elsif content_type.to_s.start_with?("image/")
        content_tag(:figure, class: "attachment attachment--preview") do
          image = image_tag(url, skip_pipeline: true, alt: filename.to_s)
          caption_tag = caption.present? ? content_tag(:figcaption, caption, class: "attachment__caption") : "".html_safe
          image + caption_tag
        end
      end
    end

    def attachment_unavailable_placeholder
      content_tag(:span, t("shared.attachment_unavailable"), class: "attachment-placeholder", data: { attachment: "unavailable" })
    end

    def node_to_hash(node)
      h = node.attribute_nodes.to_h { |a| [ a.name, a.value ] }
      Object.new.tap do |o|
        o.define_singleton_method(:[]) { |k| h[k.to_s].presence || h[k.to_s.to_sym] }
        o.define_singleton_method(:[]=) { |k, v| h[k.to_s] = v }
        o.define_singleton_method(:key?) { |k| h.key?(k.to_s) }
      end
    end
end
