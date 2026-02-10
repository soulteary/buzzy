module ActionText
  module Extensions
    module RichText
      extend ActiveSupport::Concern

      included do
        # This overrides the default :embeds association!
        has_many_attached :embeds do |attachable|
          ::Attachments::VARIANTS.each do |variant_name, variant_options|
            attachable.variant variant_name, **variant_options, process: :immediately
          end
        end

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

        def normalize_action_text_attachment_gids_to_sgids
          return if body.blank?

          fragment = Nokogiri::HTML.fragment(raw_body_html)
          changed = false
          fragment.css("action-text-attachment[gid]").each do |node|
            gid = GlobalID.parse(node["gid"])
            next unless gid
            record = gid.find
            node["sgid"] = record.attachable_sgid
            node.remove_attribute("gid")
            changed = true
          rescue ActiveRecord::RecordNotFound, GlobalID::IdentificationError
            # Leave node unchanged if attachable no longer exists or gid invalid
          end
          self.body = fragment.to_html if changed
        end

        # Lexxy 提交的 mention 节点常带有被多次转义的 content，预览时会显示 ☒。
        # 保存时去掉 mention 的 content 属性并清空节点内部文本/子节点，仅保留 sgid/content-type，
        # 展示时由 attachable 局部视图渲染；否则节点内可能残留 ☒ 等占位符并被默认渲染输出。
        # 若 mention 节点仅有 gid 而无 sgid（如 normalize 未匹配到），在此处补写 sgid，避免展示时解析为未知用户。
        # 同时通过 sgid 解析为 User 的节点也视为 mention（兜底，防止 content-type 被丢弃）。
        def strip_mention_content_attribute
          return if body.blank?

          fragment = Nokogiri::HTML.fragment(raw_body_html)
          changed = false
          fragment.css("action-text-attachment").each do |node|
            next unless mention_node?(node)
            if node["gid"].present? && node["sgid"].blank?
              begin
                gid = GlobalID.parse(node["gid"])
                if gid
                  record = gid.find
                  node["sgid"] = record.attachable_sgid
                  node.remove_attribute("gid")
                  changed = true
                end
              rescue ActiveRecord::RecordNotFound, GlobalID::IdentificationError
                # Leave node unchanged if attachable no longer exists or gid invalid
              end
            end
            had_content_attr = node["content"].present?
            had_inner = node.content.present?
            node.remove_attribute("content")
            node.content = ""
            changed = true if had_content_attr || had_inner
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
