module RichTextHelper
  include ActionText::ContentHelper

  # 渲染富文本时用 attachable 局部视图替换所有 action-text-attachment 节点，
  # 避免 Lexxy 编辑器中 @mention 等保存后因 content 被转义而显示为 ☒。
  # mention 类型统一走 via/vium 渲染，不经过 render_action_text_attachment，避免 Rails 默认回退到节点内容。
  def rich_text_with_attachments(rich_text)
    return "" if rich_text.blank?

    content = rich_text.body.render_attachments do |attachment|
      content_type = attachment.respond_to?(:node) && attachment.node&.[]("content-type").to_s
      # 优先按 content-type 判断；若无 content-type 但 attachable 是 User 也走 mention 渲染（兜底）
      is_mention = content_type.downcase.include?("mention")
      is_mention = is_mention || (attachment.attachable.is_a?(User) rescue false)
      if is_mention
        render "via/vium", vium: attachment
      else
        render_action_text_attachment(attachment)
      end
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      # sgid 无效时若节点为 mention 仍展示「未知用户」
      is_mention = is_mention || (attachment.node&.[]("content-type").to_s.downcase.include?("mention"))
      is_mention ? render("users/missing_attachable") : ""
    rescue ActionView::MissingTemplate, NoMethodError
      is_mention = is_mention || (attachment.node&.[]("content-type").to_s.downcase.include?("mention"))
      is_mention ? render("users/missing_attachable") : attachment.to_html
    end
    sanitize_action_text_content(content)
  end

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
end
