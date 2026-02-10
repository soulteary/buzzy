module ApplicationHelper
  # Root-level manifest URL so Forward Auth does not redirect (avoids CORS).
  # Override via PWA_MANIFEST_BASE_URL when the public origin differs (e.g. behind proxy).
  def pwa_manifest_root_url
    base = ENV["PWA_MANIFEST_BASE_URL"].presence || request.base_url
    base.to_s.sub(/\/*\z/, "") + "/manifest.json"
  end

  def available_locales_for_select
    Rails.application.config.i18n.available_locales.map { |locale| [ t("locales.name.#{locale}", default: locale.to_s), locale.to_s ] }
  end

  # 当前界面显示使用的语言（用于设置页等展示）
  def current_display_locale
    I18n.locale
  end

  def page_title_tag
    account_name = if Current.account && Current.session&.identity&.users&.many?
      Current.account&.name
    end
    tag.title [ @page_title, account_name, "Buzzy" ].compact.join(" | ")
  end

  def icon_tag(name, **options)
    tag.span class: class_names("icon icon--#{name}", options.delete(:class)), "aria-hidden": true, **options
  end

  def back_link_to(label, url, action, **options)
    data = (options.delete(:data) || {}).reverse_merge(controller: "hotkey", action: action, turbo_prefetch: false)
    link_to url, class: "btn btn--back btn--circle-mobile", data: data, **options do
      icon_tag("arrow-left") + tag.strong(t("shared.back_to_label", label: label), class: "overflow-ellipsis") + tag.kbd("ESC", class: "txt-x-small hide-on-touch").html_safe
    end
  end

  # When true, Forward Auth is enabled and logout should be hidden/disabled.
  def forward_auth_enabled?
    cfg = Rails.application.config.forward_auth
    cfg.is_a?(ForwardAuth::Config) && cfg.enabled?
  end

  # When true, current user is a super admin (email in ADMIN_EMAILS) and can view all boards and the admin overview page.
  def super_admin?
    return false if Current.identity.blank?
    email = Current.identity.email_address.to_s.strip.downcase
    return false if email.blank?
    Buzzy.admin_emails.include?(email)
  end

  # When false, do not render any email display in the UI (hide email elements).
  def show_email_in_ui?
    !Buzzy.hide_emails?
  end

  # Returns the email to display in the UI. When Buzzy.hide_emails? is true, returns blank so elements can be hidden.
  def display_email(email)
    return "" if email.blank?
    return "" if Buzzy.hide_emails?
    email.to_s
  end

  # For use in sentences like "Sent to …". When hiding, returns a generic "your email" so the sentence still reads well.
  def display_email_in_sentence(email)
    return "" if email.blank?
    return t("shared.your_email") if Buzzy.hide_emails?
    email.to_s
  end

  # 当前身份是否可在该卡片上发评论（同账号可编辑、仅提及/公开可访问、跨账号仅公开可访问均可；用于决定是否展示评论表单）
  def current_identity_can_comment_on?(card)
    return false unless card.present? && card.published?
    if Current.user.present?
      return true if card_editable_by_current_user?(card) || board_accessed_via_mention? || card_from_other_account?(card)
    end
    if Current.user.blank? && Current.identity.present?
      board = card.board
      return true if board_accessed_via_mention? || board&.all_access?
    end
    false
  end

  # 评论表单中用于展示头像等的用户（跨账号且 Current.user 为空时取身份下任一用户，与 create 时 set_user_for_cross_account_comment 一致）
  def user_for_comment_form_display(card)
    return Current.user if Current.user.present?
    return nil unless current_identity_can_comment_on?(card) && Current.identity.present?
    Current.identity.users.first
  end
end
