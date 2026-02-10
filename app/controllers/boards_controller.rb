class BoardsController < ApplicationController
  include FilterScoped

  skip_before_action :require_user_in_account, only: :show, if: :viewing_other_user_resource?
  allow_unauthorized_access only: :show, if: :viewing_other_user_resource?

  before_action :set_board, except: %i[ index new create ]
  before_action :ensure_permission_to_admin_board, only: %i[ edit update destroy ]
  before_action :ensure_board_editable, only: %i[ update destroy ]

  # 在用户上下文（查看他人看板）下使用被查看用户的 filter，以便正确展示该用户的卡片列表
  def set_filter
    user = filter_user_for_board
    if user.blank?
      redirect_to main_app.session_menu_path(script_name: nil) and return
    end
    if params[:filter_id].present?
      @filter = user.filters.find(params[:filter_id])
    else
      @filter = user.filters.from_params filter_params
    end
  end

  def set_user_filtering
    user = filter_user_for_board
    @user_filtering = User::Filtering.new(user, @filter, expanded: expanded_param)
  end

  def index
    set_page_and_extract_portion_from boards_scope.includes(:creator, :account)
  end

  def show
    if @filter.used?(ignore_boards: true)
      show_filtered_cards
    else
      show_columns
    end
  end

  def new
    @board = Board.new
  end

  def create
    @board = Board.create! board_params.with_defaults(all_access: false)

    respond_to do |format|
      format.html { redirect_to user_board_path(@board.url_user, @board) }
      format.json { head :created, location: user_board_path(@board.url_user, @board, format: :json) }
    end
  end

  def edit
    selected_user_ids = @board.users.ids
    @selected_users, @unselected_users = \
      @board.account.users.active.alphabetically.includes(:identity).partition { |user| selected_user_ids.include? user.id }
  end

  def update
    @board.update! board_params
    @board.accesses.revise granted: grantees, revoked: revokees if grantees_changed?

    respond_to do |format|
      format.html do
        if @board.accessible_to?(Current.user)
          redirect_to edit_user_board_path(@board.url_user, @board), notice: I18n.t("account.saved")
        else
          redirect_to root_path, notice: I18n.t("account.saved_removed_from_board")
        end
      end
      format.json { head :no_content }
    end
  end

  def destroy
    @board.destroy

    respond_to do |format|
      format.html { redirect_to root_path }
      format.json { head :no_content }
    end
  end

  private
    def boards_scope
      # 从 params 或路径解析「被查看用户」：嵌套路由为 /users/:user_id/boards，member 路由为 /users/:id/boards，均可能只从路径带出用户
      profile_user_id = params[:user_id].presence || request.path.match(%r{\busers/([0-9a-f-]{36})\b}i)&.captures&.first
      if profile_user_id.present? && Current.account.present?
        # 跨账号链接可能携带了「其他账号用户」的 user_id（例如从提及/聚合页进入）。
        # 这种情况下不应直接 404，而是回退到默认看板可见范围继续解析 board_id。
        user = Current.account.users.active.find_by(id: profile_user_id)
        if user.present?
          base = boards_visible_when_viewing_user(user) || user.boards
          return base.where(account_id: Current.account.id)
        end
      end

      if super_admin?
        Current.account.boards
      else
        Current.account_single_user? ? Current.account.boards : Current.user.boards
      end
    end

    def set_board
      @board = boards_scope.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      # 看板可能属于其他账号（例如从「全部内容」点进），重定向到规范 user 路径
      board = Board.find_by(id: params[:id])
      if board && board.account_id != Current.account&.id && (super_admin? || board.accessible_to?(Current.user))
        # 先切换到看板所属账号，再生成目标路径，避免重定向到当前错误账号前缀导致循环。
        Current.account = board.account
        canonical_path = user_board_path(board.url_user, board, script_name: board.account.slug)
        if request.path == canonical_path
          @board = board
          return
        end
        redirect_to canonical_path, status: :moved_permanently and return
      end
      @board = find_board_by_mention_fallback
      raise ActiveRecord::RecordNotFound if @board.blank?
    end

    # 被 @ 提及/指派用户可进入非公开看板详情页，仅见其可见卡片（受限视图）
    def find_board_by_mention_fallback
      board = Board.find_by(id: params[:id])
      return nil if board.blank?

      if board.all_access? && (Current.account.blank? || Current.account.id != board.account_id)
        Current.account = board.account
        @board_from_public_fallback = true
        return board
      end

      if Current.user.present? && Current.user.cards_visible_in_board_for_limited_view(board).exists?
        Current.account = board.account if Current.account&.id != board.account_id
        @board_accessed_via_mention = true
        return board
      end

      if Current.identity.present?
        mention_user = Current.identity.users.find { |u| u.cards_visible_in_board_for_limited_view(board).exists? }
        if mention_user.present?
          Current.user_before_fallback = Current.user
          Current.user = mention_user
          Current.account = board.account
          @board_accessed_via_mention = true
          return board
        end
      end

      nil
    end

    def grantees_changed?
      params.key?(:user_ids)
    end

    def show_filtered_cards
      if @board_accessed_via_mention && Current.user.present?
        cards_scope = Current.user.cards_visible_in_board_for_limited_view(@board).published
        set_page_and_extract_portion_from cards_scope
      else
        @filter.board_ids = [ @board.id ]
        cards_scope = viewing_board_as_limited_viewer? ? @filter.cards.published : @filter.cards
        set_page_and_extract_portion_from cards_scope
      end
    end

    def show_columns
      if @board_accessed_via_mention && Current.user.present?
        cards = Current.user.cards_visible_in_board_for_limited_view(@board).published
          .awaiting_triage.latest.with_golden_first.preloaded
        set_page_and_extract_portion_from cards
      else
        cards = @board.cards.awaiting_triage.latest.with_golden_first.preloaded
        cards = cards.published if viewing_board_as_limited_viewer?
        set_page_and_extract_portion_from cards
      end
      fresh_when etag: [ @board, @page.records, @user_filtering, Current.account ]
    end

    def viewing_board_as_limited_viewer?
      viewing_other_user_as_limited_viewer?
    end

    def board_params
      permitted = [ :name, :auto_postpone_period, :public_description ]
      # create 时 @board 未设置；新建看板的创建者即当前用户，允许设置 all_access
      if @board
        permitted << :all_access if @board.visibility_changeable_by?(Current.user)
      elsif Current.user.present?
        permitted << :all_access
      end
      params.expect(board: permitted)
    end


    def grantees
      @board.account.users.active.where id: grantee_ids
    end

    def revokees
      @board.users.where.not id: grantee_ids
    end

    def grantee_ids
      params.fetch :user_ids, []
    end

    def filter_user_for_board
      (params[:user_id].present? && Current.context_user) || Current.user || filter_user_for_public_board
    end

    # 查看其他账户的公开看板时无 Current.user，用看板创建者作为 filter 上下文，避免 set_filter 重定向到 session menu
    def filter_user_for_public_board
      return nil unless @board&.all_access? && @board.account_id == Current.account&.id && Current.user.blank?
      @board.creator
    end
end
