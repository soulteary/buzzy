# frozen_string_literal: true

module ActionText
  # Single source of truth for resolving a User from an action-text-attachment mention node.
  # Used by save (action_text.rb), render (rich_text_helper), and export (card/exportable)
  # so that sgid expiry or invalid signature does not cause "unknown user";
  # we try sgid first, then gid, and only show missing when both fail.
  # 使用 User.unscoped 确保跨账号查找，不局限于当前 account。
  module MentionResolver
    class << self
      # @param node [Object] something indexable for "sgid", "gid", "user_id"/"id", "handle"/"data-handle"
      # @return [User, nil] the User if resolvable, otherwise nil
      def resolve_user(node)
        return nil if node.blank?

        user = from_sgid(value_from(node, "sgid"))
        return user if user.is_a?(::User)

        user = from_gid(value_from(node, "gid"))
        return user if user.is_a?(::User)

        user = from_user_id(value_from(node, "user_id") || value_from(node, "id") || value_from(node, "data-user-id"))
        return user if user.is_a?(::User)

        from_handle(value_from(node, "handle") || value_from(node, "data-handle"))
      end

      private

      def value_from(node, key)
        node[key].to_s.presence || node[key.to_sym].to_s.presence
      end

      def from_sgid(sgid)
        return nil if sgid.blank?

        # Prefer ActionText locator purpose, but tolerate legacy/malformed sgid purpose
        # so persisted mentions do not degrade to "unknown user".
        parsed = SignedGlobalID.parse(sgid, for: Attachable::LOCATOR_NAME) || SignedGlobalID.parse(sgid)
        return nil unless parsed && parsed.model_class == ::User

        # Prefer framework locator first (keeps ActionText/GID behavior), then
        # fallback to unscoped find for cross-account safety.
        record = begin
          parsed.find
        rescue ActiveRecord::RecordNotFound
          ::User.unscoped.find_by(id: parsed.model_id)
        end

        record.is_a?(::User) ? record : nil
      rescue ActiveSupport::MessageVerifier::InvalidSignature, URI::InvalidURIError, GlobalID::IdentificationError
        nil
      end

      def from_gid(gid)
        return nil if gid.blank?

        g = GlobalID.parse(gid)
        return nil unless g && g.model_class == ::User

        # Prefer GlobalID lookup first, then fallback to unscoped find.
        record = begin
          g.find
        rescue ActiveRecord::RecordNotFound
          ::User.unscoped.find_by(id: g.model_id)
        end

        record.is_a?(::User) ? record : nil
      rescue GlobalID::IdentificationError, URI::InvalidURIError
        nil
      end

      def from_user_id(user_id)
        return nil if user_id.blank?

        id = user_id.to_s.strip
        return nil unless id.match?(/\A\d+\z/) || id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)

        record = ::User.unscoped.active.find_by(id: id)
        record.is_a?(::User) ? record : nil
      rescue ActiveRecord::RecordNotFound
        nil
      end

      def from_handle(handle)
        return nil if handle.blank?

        h = handle.to_s.strip.downcase
        return nil if h.blank?

        record = ::User.unscoped.active.joins(:identity).where(identities: { id: ::Identity.by_email_prefix(h).select(:id) }).take
        record.is_a?(::User) ? record : nil
      end
    end
  end
end
