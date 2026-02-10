module User::Attachable
  extend ActiveSupport::Concern

  included do
    include ActionText::Attachable

    def attachable_plain_text_representation(...)
      "@#{first_name.downcase}"
    end

    # 用于 @mention token 的标识，与用户资料邮箱前缀一致（如 xiaoming.zhang@mail.com → xiaoming.zhang）
    def mention_handle
      return nil if identity.blank?
      local = identity.email_address.to_s.strip.split("@", 2).first
      local.presence&.downcase
    end
  end
end
