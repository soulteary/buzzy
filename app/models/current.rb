class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user, :identity, :account, :context_user
  # 跨账号 fallback 时暂存的「请求方用户」；Pin 等操作需用此用户而非 fallback 后的 mention_user
  attribute :user_before_fallback
  attribute :http_method, :request_id, :user_agent, :ip_address, :referrer

  def session=(value)
    super(value)

    if value.present?
      self.identity = session.identity
    end
  end

  def identity=(identity)
    super(identity)

    if identity.present?
      self.user = identity.users.find_by(account: account)
    end
  end

  def with_account(value, &)
    with(account: value, &)
  end

  def without_account(&)
    with(account: nil, &)
  end

  # Single-real-user account/workspace mode: one non-system member in current account.
  # Used to short-circuit board scope/permissions and skip Access joins.
  def account_single_user?
    return false if account.blank?
    account.users.active.where.not(role: :system).one?
  end
end
