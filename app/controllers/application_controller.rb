class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include BlockSearchEngineIndexing
  include CurrentRequest, CurrentTimezone, SetLocale, SetPlatform
  include RequestForgeryProtection
  include TurboFlash, ViewTransitions
  include RoutingHeaders

  # 必须在 require_account 之前执行：访问 /users/:id 时根据被查看用户设置 Current.account
  prepend_before_action :set_account_from_user_path
  before_action :set_context_user

  helper_method :super_admin?, :account_single_user?, :viewing_other_user_as_limited_viewer?, :board_accessed_via_mention?, :card_editable_by_current_user?, :card_deletable_by_current_user?, :card_pinnable_by_current_user?, :card_from_other_account?, :pinning_user_for

  # When true, current user is a super admin (email in ADMIN_EMAILS) and can view all boards and the admin overview page.
  def super_admin?
    return false if Current.identity.blank?
    email = Current.identity.email_address.to_s.strip.downcase
    return false if email.blank?
    Buzzy.admin_emails.include?(email)
  end

  def account_single_user?
    Current.account_single_user?
  end

  # Turbo Frame 请求遇到 404 时若未返回对应 id 的 frame，Turbo 会显示 "Content missing"；此处统一返回空 frame 避免该提示
  rescue_from ActiveRecord::RecordNotFound do |exception|
    if turbo_frame_request?
      frame_id = request.headers["Turbo-Frame"].to_s.gsub(%r{[^\w\-]}, "")
      if frame_id.present?
        render html: content_tag("turbo-frame", "", id: frame_id), layout: false, status: :not_found
      else
        raise exception
      end
    else
      raise exception
    end
  end

  etag { "v1" }
  stale_when_importmap_changes
  allow_browser versions: :modern

  def default_url_options
    if Current.account.present?
      (super || {}).merge(script_name: Current.account.slug)
    else
      super || {}
    end
  end

  # 从「其他用户 最近在做什么？」等入口查看他人看板/卡片时，允许 Current.user 为空（当前身份可能不在被查看用户所在 account）
  # member 路由为 /users/:id/boards，嵌套为 /users/:user_id/boards/:id，均需视为「查看他人资源」
  def viewing_other_user_resource?
    params[:user_id].present? || Current.context_user.present?
  end

  # 查看某用户资料/动态时，该用户项目（看板）的可见范围：本人或管理员可见全部；普通用户/访客可见「对所有人可见」(all_access) 的看板，以及「已添加当前登录用户」的看板。
  def boards_visible_when_viewing_user(profile_user)
    return nil if Current.user == profile_user
    return profile_user.boards if super_admin?
    return profile_user.boards if Current.user&.admin?
    if Current.user.present?
      profile_user.boards.where(all_access: true).or(profile_user.boards.where(id: Access.where(user_id: Current.user.id).select(:board_id)))
    else
      profile_user.boards.all_access
    end
  end

  # 当前是否为「普通用户/访客查看他人」场景：仅能看「对所有人可见」的看板与已发布卡片。
  # 使用 Current.context_user（由路径 /users/:id 或 params[:user_id] 设置），不依赖 params[:user_id]，以便 member 路由如 /users/:id/boards 也生效。
  def viewing_other_user_as_limited_viewer?
    return false if Current.context_user.blank? || Current.context_user == Current.user
    return false if super_admin? || Current.user&.admin?
    true
  end

  # 仅因 @ 提及或仅因公开看板可访问时为 true（用于视图中隐藏编辑/删除/关注等入口）；CardsController 设置 @board_from_public_fallback / @board_accessed_via_mention
  def board_accessed_via_mention?
    @board_accessed_via_mention.present? || @board_from_public_fallback.present?
  end

  # 当前用户是否属于卡片所属账号且非仅因提及/公开可访问（为 true 时允许编辑卡片内容；跨账号用户只能评论）
  def card_editable_by_current_user?(card)
    return false if card.blank?
    Current.user.present? && Current.user.account_id == card.account_id && !board_accessed_via_mention?
  end

  # 仅卡片的创建者或账号管理员在非「仅因提及/公开」访问时可见并使用删除卡片功能；其他用户不展示删除入口
  def card_deletable_by_current_user?(card)
    return false if card.blank?
    Current.user.present? && Current.user.can_administer_card?(card) && !board_accessed_via_mention?
  end

  # 是否允许当前身份将卡片 pin 到自己的界面（同账号可编辑 或 本账号内提及可见；跨账号访问时不允许置顶）
  def card_pinnable_by_current_user?(card)
    return false if card.blank?
    requesting_user = Current.user_before_fallback.presence || Current.user
    return false if requesting_user.present? && requesting_user.account_id != card.account_id
    card_editable_by_current_user?(card) || (board_accessed_via_mention? && Current.identity.present?)
  end

  # 用于 Pin 状态与 pin_by 的用户：同账号为 Current.user，跨账号为身份下「非卡片账号」用户（pin 到自己的 tray）
  def pinning_user_for(card)
    return nil if card.blank?
    return Current.user if card_editable_by_current_user?(card)
    return nil unless board_accessed_via_mention? && Current.identity.present?
    Current.user_before_fallback.presence || Current.identity.users.find { |u| u.account_id != card.account_id } || Current.user
  end

  # 当前用户是否属于其他账号（跨账号访问该卡片时禁止编辑/更新/删除，仅允许评论）
  # 可传入 card 以便在 partial（如 preview）中判断，未传时使用 @card
  def card_from_other_account?(card = nil)
    c = card || @card
    c.present? && Current.user.present? && Current.user.account_id != c.account_id
  end

  # 看板已锁定可编辑性时，禁止普通用户修改看板及其中卡片/列（super_admin 可绕过）
  def ensure_board_editable
    board = @board || @card&.board || @column&.board
    head :forbidden if board.present? && !board.editable_by?(Current.user)
  end

  # 普通用户查看他人时，仅允许访问「对所有人可见」或已添加自己的看板；禁止通过任何路径看到非公开看板下的卡片
  # 因 @ 提及或公开看板回退进入时跳过此限制（被提及用户可访问该卡片对应看板）
  def ensure_board_visible_to_limited_viewer
    return if @board_accessed_via_mention || @board_from_public_fallback
    return unless viewing_other_user_as_limited_viewer?
    return if @board.blank? || Current.context_user.blank? || Current.account.blank?
    visible = boards_visible_when_viewing_user(Current.context_user)
    return if visible.where(account_id: Current.account.id).exists?(@board.id)
    raise ActiveRecord::RecordNotFound
  end

  private

    def set_account_from_user_path
      # 匹配 /users/:id 或 /:script_name/users/:id，从路径取出 user id
      match = request.path.match(%r{\busers/([0-9a-f-]{36})\b}i)
      if match && (user = User.active.find_by(id: match[1]))
        Current.account = user.account if Current.account.nil?
        # 中间件可能已设置 Current.account，但未设置 Current.user，此处补全以便 require_user_in_account / ensure_can_access_account 通过
        Current.user = Current.identity&.users&.find_by(account: Current.account)
      end
    end

    def set_context_user
      user_id = params[:user_id].presence || request.path.match(%r{\busers/([0-9a-f-]{36})\b}i)&.captures&.first
      if user_id.present? && Current.account.present?
        Current.context_user = Current.account.users.active.find_by(id: user_id)
      else
        Current.context_user = nil
      end
    end
end
