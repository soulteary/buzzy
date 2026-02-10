class CardsController < ApplicationController
  include FilterScoped

  skip_before_action :require_user_in_account, only: :show, if: :show_may_view_without_user_in_account?
  allow_unauthorized_access only: :show, if: :show_may_view_without_user_in_account?
  skip_before_action :set_filter, only: :show, if: :viewing_other_user_resource?
  skip_before_action :set_user_filtering, only: :show, if: :viewing_other_user_resource?

  before_action :set_board, only: %i[ create show edit update destroy ]
  before_action :ensure_board_visible_to_limited_viewer, only: %i[ show edit update destroy ]
  before_action :set_card, only: %i[ show edit update destroy ]
  before_action :redirect_if_drafted, only: :show
  before_action :ensure_permission_to_administer_card, only: %i[ destroy ]
  before_action :ensure_board_editable, only: %i[ create update destroy ]
  before_action :ensure_not_mention_only_access, only: %i[ edit update destroy ]

  def index
    set_page_and_extract_portion_from @filter.cards
  end

  def create
    respond_to do |format|
      format.html do
        card = Current.user.draft_new_card_in(@board)
        redirect_to user_board_card_draft_path(@board.url_user, @board, card)
      end

      format.json do
        card = @board.cards.create! card_params.merge(creator: Current.user, status: "published")
        head :created, location: user_board_card_path(@board.url_user, @board, card, format: :json)
      end
    end
  end

  def show
  end

  def edit
  end

  def update
    @card.update! card_params

    respond_to do |format|
      format.html { redirect_to user_board_card_path(@board.url_user, @board, @card), notice: I18n.t("cards.card_updated") }
      format.turbo_stream
      format.json { render :show }
      format.any { redirect_to user_board_card_path(@board.url_user, @board, @card), notice: I18n.t("cards.card_updated") }
    end
  end

  def destroy
    @card.destroy!

    respond_to do |format|
      format.html { redirect_to @card.board, notice: I18n.t("cards.card_deleted") }
      format.json { head :no_content }
    end
  end

  private
    # 允许在「查看他人」或从「所有人的内容」点进卡片时，即使当前身份在该账号下无用户也可打开 show
    def show_may_view_without_user_in_account?
      viewing_other_user_resource? || (params[:board_id].present? && params[:id].present?)
    end

    def set_board
      profile_user_id = params[:user_id].presence || Current.context_user&.id
      if profile_user_id.present? && Current.account.present?
        user = Current.account.users.active.find_by(id: profile_user_id)
        if user.present?
          visible = boards_visible_when_viewing_user(user) || user.boards
          @board = visible.where(account_id: Current.account.id).find_by(id: params[:board_id])
          return if @board.present?
        end
      end

      if super_admin?
        @board = Board.find(params[:board_id])
        Current.account = @board.account if Current.account&.id != @board.account_id
      elsif Current.user.present?
        @board = find_board_for_current_user_or_mention
      elsif Current.account.present?
        # 当前身份在该账号下无用户时，优先按 board_id 全局定位，再依据公开/提及权限判定，避免受 URL 账号前缀影响误报 404。
        @board = find_board_for_public_or_mention_without_current_user
        return if @board.present?
        raise ActiveRecord::RecordNotFound
      else
        head :not_found and return
      end
    end

    def find_board_for_public_or_mention_without_current_user
      board = Board.find_by(id: params[:board_id])
      return nil if board.blank?

      if board.all_access?
        @board_from_public_fallback = true
        Current.account = board.account if Current.account&.id != board.account_id
        return board
      end

      return nil if Current.identity.blank?

      # 身份存在但当前账号下无 user 时，优先尝试身份下任一用户是否可直接访问该看板。
      # 这可覆盖跨账号 URL 前缀导致 Current.user 为空但实际有看板访问权的场景。
      board_user = Current.identity.users.find { |u| board.accessible_to?(u) }
      if board_user.present?
        Current.user_before_fallback = Current.user
        Current.user = board_user
        Current.account = board.account
        return board
      end

      # 仅按看板+编号定位卡片，避免历史数据中 card.account_id 与 board.account_id 不一致时误判 404。
      card = board.cards.published.find_by(number: params[:id])
      return nil if card.blank?

      mention_user = Current.identity.users.find { |u| card_accessible_via_direct_share?(u, card, board.account) }
      return nil if mention_user.blank?

      Current.account = board.account
      Current.user = mention_user
      @board_accessed_via_mention = true
      board
    end

    # 先按可访问看板查找；若无权限则尝试「公开看板+已发布卡片」或「因 @ 提及可访问」的卡片对应看板
    def find_board_for_current_user_or_mention
      scope = Current.account_single_user? ? Current.account.boards : Current.user.boards
      scope.find(params[:board_id])
    rescue ActiveRecord::RecordNotFound
      # 不依赖 Current.account，直接按 board_id 全局查板，避免 URL 前缀与看板所属账号不一致时 board 为 nil
      board = Board.find_by(id: params[:board_id])
      return raise if board.blank?

      # 仅按看板+编号定位卡片，避免账号字段不一致导致提及访问被提前拦截。
      card_on_board = board.cards.published.find_by(number: params[:id])
      return raise if card_on_board.blank?

      account_scope = board.account

      # 公开看板：允许参与讨论
      if board.all_access?
        @board_from_public_fallback = true
        Current.account = account_scope if Current.account&.id != account_scope.id
        return board
      end

      # 当前用户因提及或通知可访问
      if card_accessible_via_direct_share?(Current.user, card_on_board, account_scope)
        @board_accessed_via_mention = true
        Current.account = account_scope if Current.account&.id != account_scope.id
        return board
      end

      # 当前身份下任意用户因提及或通知可访问（含跨账号）
      if Current.identity.present?
        mention_user = Current.identity.users.find { |u| card_accessible_via_direct_share?(u, card_on_board, account_scope) }
        if mention_user.present?
          Current.user_before_fallback = Current.user
          Current.user = mention_user
          Current.account = account_scope
          @board_accessed_via_mention = true
          return board
        end
      end

      raise
    end

    def set_card
      # 在用户上下文（查看他人看板）下，从该看板卡片中按账号与 number 查找，不限制为当前用户可访问，以正确展示其他账号/用户的卡片
      if params[:user_id].present? && Current.account.present?
        scope = @board.cards.where(account_id: Current.account.id)
        scope = scope.published if viewing_other_user_as_limited_viewer?
        @card = scope.find_by!(number: params[:id])
      elsif @board_accessed_via_mention
        # 因 @ 提及进入：仅允许该用户通过提及/指派或通知回退可见的已发布卡片
        scope = Current.user.present? ? Current.user.cards_visible_in_board_for_limited_view(@board).published : @board.cards.published.where(account_id: @board.account_id)
        @card = scope.find_by(number: params[:id])
        if @card.blank? && Current.user.present?
          candidate = @board.cards.published.find_by(number: params[:id])
          @card = candidate if candidate.present? && card_accessible_via_direct_share?(Current.user, candidate, @board.account)
        end
        raise ActiveRecord::RecordNotFound if @card.blank?
      elsif @board_from_public_fallback
        # 仅因公开看板进入：仅允许已发布卡片，不要求在看板 Access 中
        @card = @board.cards.published.find_by!(number: params[:id])
      elsif Current.user.present?
        # 按看板所属账号限定（与 Current.account 解耦，避免未设置 Current.account 时 500），同一 number 仅存在于同一账号
        @card = @board.cards.merge(Current.user.accessible_cards).where(account_id: @board.account_id).find_by!(number: params[:id])
      else
        # 当前身份在该账号下无用户（仅能看对所有人可见的看板），只允许查看已发布卡片
        @card = @board.cards.published.where(account_id: @board.account_id).find_by!(number: params[:id])
      end
    rescue ActiveRecord::RecordNotFound
      # 卡片可能属于其他账号，重定向到该卡片所属账号的 URL（仅当当前用户有权限时）
      if Current.user.present?
        card = Current.user.accessible_cards.find_by(number: params[:id]) ||
          Current.user.cards_accessible_via_mention(Current.account).find_by(number: params[:id]) ||
          Current.user.cards_accessible_via_assignment(Current.account).find_by(number: params[:id])
        if card && card.account_id != Current.account&.id
          redirect_to user_board_card_path(card.board.url_user, card.board, card) and return
        end
      end
      raise
    end

    def redirect_if_drafted
      redirect_to user_board_card_draft_path(@board.url_user, @board, @card) if @card.drafted?
    end

    def ensure_permission_to_administer_card
      return if super_admin?
      head :forbidden if Current.user.blank?
      head :forbidden unless Current.user.can_administer_card?(@card)
    end

    # 仅因 @ 提及或仅因公开看板可访问时不允许编辑/更新/删除卡片，仅允许查看与评论；跨账号用户也不能修改其他账号的卡片
    def ensure_not_mention_only_access
      return if super_admin?
      head :forbidden if @board_accessed_via_mention || @board_from_public_fallback || card_from_other_account?
    end

    def card_params
      params.expect(card: [ :title, :description, :image, :created_at, :last_active_at ])
    end

    def card_accessible_via_direct_share?(user, card, account_scope)
      return false if user.blank? || card.blank?
      user.cards_accessible_via_mention(account_scope).exists?(id: card.id) ||
        user.cards_accessible_via_assignment(account_scope).exists?(id: card.id) ||
        user.notified_of_card?(card)
    end
end
