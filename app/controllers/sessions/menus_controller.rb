class Sessions::MenusController < ApplicationController
  disallow_account_scope

  layout "public"

  def show
    # 跟随 302 进入 session menu 的 turbo-frame 请求：整页不含该 frame id 会显示 Content missing，直接返回空 frame
    if turbo_frame_request?
      frame_id = request.headers["Turbo-Frame"].to_s.gsub(%r{[^\w\-]}, "")
      if frame_id.present?
        render html: content_tag("turbo-frame", "", id: frame_id), layout: false, status: :ok and return
      end
    end

    @accounts = Current.identity.accounts.active

    # 仅在全页访问且只有一个账号时重定向；Turbo Frame 或其它嵌入请求一律渲染菜单，避免循环重定向导致 Content missing
    if !turbo_frame_request? && !request.xhr? && @accounts.one?
      account = @accounts.first
      user = Current.identity.users.find_by(account: account)
      if user
        redirect_to user_path(user, script_name: nil) and return
      else
        redirect_to root_url(script_name: account.slug) and return
      end
    end

    # When user has no accounts: auto-create one for Forward Auth user so they never see the no-accounts page.
    if @accounts.empty? && forward_auth_auto_create_account?
      account = create_account_for_forward_auth_identity
      redirect_to root_url(script_name: account.slug) and return if account
    end
  end

  private

    def forward_auth_config
      Rails.application.config.forward_auth
    end

    def forward_auth_auto_create_account?
      cfg = forward_auth_config
      cfg.is_a?(ForwardAuth::Config) && cfg.enabled? && cfg.auto_provision? && cfg.auto_create_account?
    end

    def create_account_for_forward_auth_identity
      cfg = forward_auth_config
      owner_name = email_local_part(Current.identity.email_address)
      account = Account.create_with_owner(
        account: { name: cfg.auto_create_account_name },
        owner: { identity: Current.identity, name: owner_name }
      )
      account.setup_customer_template
      # 邮箱来自 forward auth，禁止修改以免产生僵尸账号
      if Current.identity.respond_to?(:email_locked=)
        Current.identity.update_column(:email_locked, true)
      end
      account
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "[ForwardAuth] Auto-create account failed: #{e.message}"
      nil
    end

    def email_local_part(email_address)
      email_address.to_s.split("@", 2).first.presence || email_address
    end
end
