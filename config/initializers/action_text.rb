require "cgi"

module ActionText
  module Extensions
    module RichText
      extend ActiveSupport::Concern

      included do
        # This overrides the default :embeds association!
        has_many_attached :embeds do |attachable|
          ::Attachments::VARIANTS.each do |variant_name, variant_options|
            attachable.variant variant_name, **variant_options, preprocessed: true
          end
        end

        before_save :sync_markdown_and_body, if: :body_changed?
        before_save :normalize_action_text_attachment_gids_to_sgids, if: :body_changed?
        before_save :strip_mention_content_attribute, if: :body_changed?
      end

      # Delegate storage tracking to the parent record (Card, Comment, Board, etc.)
      def storage_tracked_record
        record.try(:storage_tracked_record)
      end

      def accessible_to?(user)
        record.try(:accessible_to?, user) || record.try(:publicly_accessible?)
      end

      def publicly_accessible?
        record.try(:publicly_accessible?)
      end

      private
        # 统一以 Markdown 作为编辑与存储来源：
        # - 入参为 Markdown：写入 body_markdown，并转换为 HTML 存入 body（供 ActionText 渲染/关联）。
        # - 入参为 HTML：回填 body_markdown，避免再次编辑时展示原始 HTML。
        def sync_markdown_and_body
          return if body.blank?

          source = raw_body_html
          if MarkdownRenderer.looks_like_markdown?(source)
            self.body_markdown = source.to_s if has_attribute?(:body_markdown)
            self.body = MarkdownRenderer.to_html(source)
          elsif has_attribute?(:body_markdown)
            self.body_markdown = HtmlToMarkdown.convert(source)
          end
        end

        # 使用原始 HTML（未渲染的 fragment），避免 body.to_s 返回 to_rendered_html_with_layout 导致
        # 匹配不到 action-text-attachment 节点、normalize/strip 不生效。
        def raw_body_html
          if body.respond_to?(:fragment) && body.fragment.present?
            body.fragment.to_html
          elsif body.respond_to?(:to_html)
            body.to_html
          else
            body.to_s
          end
        end

        # 将仅带 gid 的节点转为 sgid。保留 gid 作为渲染回退（sgid 无效时仍可解析 attachable）。
        def normalize_action_text_attachment_gids_to_sgids
          return if body.blank?

          fragment = Nokogiri::HTML.fragment(raw_body_html)
          changed = false
          fragment.css("action-text-attachment[gid]").each do |node|
            gid = GlobalID.parse(node["gid"])
            next unless gid
            record = gid.find
            node["sgid"] = record.attachable_sgid
            # 保留 gid：不仅 mention，普通附件也可在 sgid 失效时回退渲染，避免页面显示 ☒。
            changed = true
          rescue ActiveRecord::RecordNotFound, GlobalID::IdentificationError
            # Leave node unchanged if attachable no longer exists or gid invalid
          end
          self.body = fragment.to_html if changed
        end

        # Lexxy 提交的 mention 节点常带有被多次转义的 content，预览时会显示 ☒。
        # 保存时去掉 mention 的 content 属性，用可解析到的用户展示名填充节点内容（便于再次编辑时显示姓名而非 x）；
        # 若无法解析则清空节点内容。展示时由 attachable 局部视图渲染。
        # 若 mention 节点仅有 gid 而无 sgid，在此处补写 sgid；mention 节点保留 gid 作为渲染回退。
        def strip_mention_content_attribute
          return if body.blank?

          fragment = Nokogiri::HTML.fragment(raw_body_html)
          mention_nodes = fragment.css("action-text-attachment").select { |node| mention_node?(node) }
          if Rails.env.development? && mention_nodes.any?
            with_sgid = mention_nodes.count { |n| n["sgid"].present? }
            with_gid_only = mention_nodes.count { |n| n["sgid"].blank? && n["gid"].present? }
            with_no_id = mention_nodes.count { |n| n["sgid"].blank? && n["gid"].blank? }
            Rails.logger.debug "[ActionText mention] record=#{record.class.name}##{record.try(:id)} nodes=#{mention_nodes.size} sgid=#{with_sgid} gid_only=#{with_gid_only} no_sgid_gid=#{with_no_id}"
          end
          changed = false
          fragment.css("action-text-attachment").each do |node|
            next unless mention_node?(node)
            raw_mention_content = node["content"].to_s
            if node["gid"].present? && node["sgid"].blank?
              begin
                gid = GlobalID.parse(node["gid"])
                if gid
                  mention_user = gid.find
                  node["sgid"] = mention_user.attachable_sgid if mention_user.respond_to?(:attachable_sgid)
                  # 保留 gid 作为渲染回退，不 remove_attribute("gid")
                  changed = true
                end
              rescue ActiveRecord::RecordNotFound, GlobalID::IdentificationError
                # Leave node unchanged if attachable no longer exists or gid invalid
              end
            end
            had_content_attr = node["content"].present?
            had_inner = node.content.present?
            node.remove_attribute("content")
            # 用共用解析器得到 User，写 gid + 展示名，再次编辑时 Lexxy 可显示姓名而非 x
            mention_user = ActionText::MentionResolver.resolve_user(node)
            mention_user ||= infer_mention_user_from_content(raw_mention_content)
            if mention_user
              node.content = mention_user.attachable_plain_text_representation
              node["gid"] = mention_user.to_global_id.to_s if node["gid"].blank?
              node["sgid"] = mention_user.attachable_sgid if node["sgid"].blank?
              if Rails.env.development? && raw_mention_content.present?
                Rails.logger.debug "[ActionText mention] inferred_from_content=true user_id=#{mention_user.id} record=#{record.class.name}##{record.try(:id)}"
              end
            else
              # 保持可见文本，避免再次编辑时显示 ☒ 占位符
              node.content = I18n.t("users.missing_attachable_label", default: "Unknown user")
            end
            changed = true
          end
          self.body = fragment.to_html if changed
        end

        def mention_node?(node)
          return true if node["content-type"].to_s.downcase.include?("mention")
          sgid_decodes_to_user?(node)
        end

        def sgid_decodes_to_user?(node)
          sgid = node["sgid"].to_s.presence
          return false if sgid.blank?
          parsed = SignedGlobalID.parse(sgid, for: ActionText::Attachable::LOCATOR_NAME) rescue nil
          parsed && parsed.model_class == ::User
        end

        # Lexxy 某些输入会把用户信息仅放在 content 属性里（常见为转义后的 <img src="/users/:id/avatar">）。
        # 当 sgid/gid 都不可用时，从该内容反推用户并补写 gid/sgid，避免保存后退化为「未知用户」。
        def infer_mention_user_from_content(raw)
          return nil if raw.blank?

          decoded = CGI.unescapeHTML(raw).to_s.strip
          decoded = decoded.sub(/\A"/, "").sub(/"\z/, "").strip
          return nil if decoded.blank?

          fragment = Nokogiri::HTML.fragment(decoded)
          img_src = fragment.at_css("img")&.[]("src").to_s
          return nil if img_src.blank?

          user_id = img_src[%r{\/users\/([^\/]+)\/avatar}, 1]
          return nil if user_id.blank?

          ::User.unscoped.find_by(id: user_id)
        rescue Nokogiri::XML::SyntaxError, ArgumentError
          nil
        end
    end
  end
end

ActiveSupport.on_load(:action_text_rich_text) do
  include ActionText::Extensions::RichText
end

# 被 @ 的用户删除后，attachable 会变成 MissingAttachable，to_plain_text / mentionable_content 会调用
# attachable_plain_text_representation，若不定义会 NoMethodError。
# 另外允许 sgid 为 nil（如节点只有 gid 且未转换），避免 SignedGlobalID.parse(nil) 报错导致整段渲染失败、页面显示 ☒。
Rails.application.config.to_prepare do
  ActionText::Attachables::MissingAttachable.class_eval do
    def initialize(sgid)
      @sgid = sgid.present? ? SignedGlobalID.parse(sgid, for: ActionText::Attachable::LOCATOR_NAME) : nil
    end

    def attachable_plain_text_representation(*)
      I18n.t("users.missing_attachable_label", default: "Unknown user")
    end
  end
end
