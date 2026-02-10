module Authentication
  extend ActiveSupport::Concern
  include ActionView::Helpers::TagHelper

  included do
    prepend_before_action :set_account_from_identity_when_single
    before_action :require_account # Checking and setting account must happen first
    before_action :require_authentication
    before_action :require_user_in_account # Identity has a user in current account
    helper_method :authenticated?
    helper_method :email_address_pending_authentication

    etag { Current.identity.id if authenticated? }

    include Authentication::ViaMagicLink, LoginHelper
  end

  class_methods do
    def require_unauthenticated_access(**options)
      allow_unauthenticated_access **options
      before_action :redirect_authenticated_user, **options
    end

    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      before_action :resume_session, **options
      allow_unauthorized_access **options
    end

    def disallow_account_scope(**options)
      skip_before_action :require_account, **options
      before_action :redirect_tenanted_request, **options
    end
  end

  private
    # 当 URL 无 account slug（如直接打开 /my/timezone）时，若已登录且仅有一个账号，则据此设置 Current.account，
    # 避免 require_account 重定向到 session menu 导致与 session menu 页内链接（如时区表单）形成 302 循环。
    def set_account_from_identity_when_single
      return if Current.account.present?
      resume_session
      if Current.identity.present? && (accounts = Current.identity.accounts.active).one?
        Current.account = accounts.first
        Current.user = Current.identity.users.find_by(account: Current.account)
      end
    end

    def authenticated?
      Current.identity.present?
    end

    def require_account
      unless Current.account.present?
        return render_empty_turbo_frame_for_session_redirect if turbo_frame_request? && request.headers["Turbo-Frame"].present?
        redirect_to main_app.session_menu_path(script_name: nil)
      end
    end

    def require_user_in_account
      if Current.account.present? && Current.identity.present? && Current.user.blank?
        return render_empty_turbo_frame_for_session_redirect if turbo_frame_request? && request.headers["Turbo-Frame"].present?
        redirect_to main_app.session_menu_path(script_name: nil)
      end
    end

    # Turbo Frame 请求被重定向到 session menu 时，整页内容不含该 frame id，会显示 "Content missing"；改为返回空 frame
    def render_empty_turbo_frame_for_session_redirect
      frame_id = request.headers["Turbo-Frame"].to_s.gsub(%r{[^\w\-]}, "")
      return redirect_to main_app.session_menu_path(script_name: nil) if frame_id.blank?
      render html: content_tag("turbo-frame", "", id: frame_id), layout: false, status: :ok
    end

    def require_authentication
      # Prefer gateway identity when request has trusted Forward Auth headers so an old session does not override.
      authenticate_by_forward_auth || resume_session || authenticate_by_bearer_token || request_authentication
    end

    def resume_session
      if session = find_session_by_cookie
        set_current_session session
      end
    end

    def find_session_by_cookie
      Session.find_signed(cookies.signed[:session_token])
    end

    def authenticate_by_bearer_token
      if request.authorization.to_s.include?("Bearer")
        authenticate_or_request_with_http_token do |token|
          if identity = Identity.find_by_permissable_access_token(token, method: request.method)
            Current.identity = identity
          end
        end
      end
    end

    def authenticate_by_forward_auth
      config = Rails.application.config.forward_auth
      if config.blank? || !config.is_a?(ForwardAuth::Config)
        Rails.logger.debug "[ForwardAuth] Skipped: not configured"
        return false
      end
      unless config.enabled?
        Rails.logger.debug "[ForwardAuth] Skipped: disabled"
        return false
      end
      unless config.trusted?(request)
        Rails.logger.info "[ForwardAuth] Skipped: request not trusted (remote_ip=#{request.remote_ip.inspect})"
        return false
      end

      email = request.headers["X-Auth-Email"].to_s.strip.downcase.presence
      if email.blank? || !URI::MailTo::EMAIL_REGEXP.match?(email)
        Rails.logger.info "[ForwardAuth] Skipped: missing or invalid X-Auth-Email"
        return false
      end

      identity = if config.auto_provision?
        Identity.find_or_create_by!(email_address: email)
      else
        Identity.find_by(email_address: email)
      end
      unless identity
        Rails.logger.info "[ForwardAuth] Skipped: no Identity for email (auto_provision=#{config.auto_provision?})"
        return false
      end

      # 若请求已处于某账户空间（URL 带 account slug），且当前 identity 在该账户下无用户，
      # 则不再自动创建用户，避免从「查看所有人」进入其他用户空间时误创建新用户。
      # 仍设置 Current.identity 并视为已认证（return true），以便控制器能基于「身份下其他账号用户」做提及/通知访问校验（如被 @ 的卡片），否则会落入 request_authentication 被重定向到登录。
      Current.identity = identity
      if Current.account.present?
        user = identity.users.find_by(account: Current.account)
        unless user
          Rails.logger.info "[ForwardAuth] Authenticated (no User in current account) identity=#{identity.id} email=#{identity.email_address}"
          return true
        end
      end

      # 邮箱来自 forward auth 网关，禁止用户在此修改，否则会产生与网关脱节的僵尸账号
      if identity.respond_to?(:email_locked=)
        identity.update_column(:email_locked, true)
      end
      start_new_session_for(identity) if config.create_session?
      Rails.logger.info "[ForwardAuth] Authenticated identity=#{identity.id} email=#{identity.email_address}"
      true
    end

    def create_forward_auth_user_in_account(identity, account, config)
      return if account.users.where.not(role: :system).exists?

      name = if config.use_email_local_part_and_lock_email?
        email_local_part(identity.email_address)
      else
        request.headers["X-Auth-User"].to_s.strip.presence || email_local_part(identity.email_address)
      end
      identity.users.create!(
        name: name,
        account: account,
        role: config.default_role,
        verified_at: Time.current
      )
    end

    def email_local_part(email_address)
      email_address.to_s.split("@", 2).first.presence || email_address
    end

    def request_authentication
      if Current.account.present?
        session[:return_to_after_authenticating] = request.url
      end

      return render_empty_turbo_frame_for_session_redirect if turbo_frame_request? && request.headers["Turbo-Frame"].present?
      redirect_to_login_url
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || landing_url
    end

    def redirect_authenticated_user
      redirect_to main_app.root_url if authenticated?
    end

    def redirect_tenanted_request
      redirect_to main_app.root_url if Current.account.present?
    end

    def start_new_session_for(identity)
      identity.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        set_current_session session
      end
    end

    def set_current_session(session)
      Current.session = session
      cookies.signed.permanent[:session_token] = { value: session.signed_id, httponly: true, same_site: :lax }
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_token)
    end

    def session_token
      cookies[:session_token]
    end
end
