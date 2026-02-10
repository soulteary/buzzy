class BoardsController < ApplicationController
  include FilterScoped

  prepend_before_action :set_account_from_public_board, only: :show
  skip_before_action :require_user_in_account, only: :show, if: :viewing_other_user_or_public_board?
  allow_unauthorized_access only: :show, if: :viewing_other_user_or_public_board?

  before_action :set_board, except: %i[ index new create ]
  before_action :redirect_script_name_board_to_user_path, only: %i[ show edit ], if: -> { request.script_name.present? && @board.present? }
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
    # 从「所有人的内容」点进其他账户的公开看板时，URL 为 /account_slug/boards/:id；若中间件未解析出 Current.account（如路径被代理改写），
    # 则根据看板 id 从公开看板反推账号，使 viewing_public_board_in_current_account? 为 true，从而跳过 require_user_in_account / ensure_can_access_account。
    def set_account_from_public_board
      return if Current.account.present? || params[:user_id].present? || params[:id].blank?
      board = Board.find_by(id: params[:id])
      return unless board&.all_access?
      Current.account = board.account
      Current.user = Current.identity&.users&.find_by(account: Current.account)
    end

    # 从「所有人的内容」点进其他账户的公开看板时，URL 为 /account_slug/boards/:id，当前身份可能不在该账户，需允许直接查看。
    # 管理员从「管理所有内容」点进其他账户的看板（含非公开）时，URL 为该账户下 /boards/:id，此时可能无 Current.user，也需允许查看。
    def viewing_other_user_or_public_board?
      viewing_other_user_resource? || viewing_public_board_in_current_account? || super_admin_viewing_board_in_current_account?
    end

    def viewing_public_board_in_current_account?
      public_board_in_current_account.present?
    end

    # 管理员在「管理所有内容」中打开其他账户下的看板时，Current.account 由 script_name 指定，但当前身份在该账户下可能无 User，需跳过 require_user_in_account
    def super_admin_viewing_board_in_current_account?
      return false unless super_admin? && Current.account.present? && params[:id].present?
      board = Board.find_by(id: params[:id])
      board&.account_id == Current.account.id
    end

    def public_board_in_current_account
      return @public_board_in_current_account if defined?(@public_board_in_current_account)
      return @public_board_in_current_account = nil unless Current.account.present? && params[:id].present?
      board = Board.find_by(id: params[:id])
      @public_board_in_current_account = (board&.account_id == Current.account.id && board&.all_access?) ? board : nil
    end

    def boards_scope
      # 从 params 或路径解析「被查看用户」：嵌套路由为 /users/:user_id/boards，member 路由为 /users/:id/boards，均可能只从路径带出用户
      profile_user_id = params[:user_id].presence || request.path.match(%r{\busers/([0-9a-f-]{36})\b}i)&.captures&.first
      if profile_user_id.present? && Current.account.present?
        user = Current.account.users.active.find(profile_user_id)
        base = boards_visible_when_viewing_user(user) || user.boards
        base.where(account_id: Current.account.id)
      elsif (board = public_board_in_current_account).present?
        Current.account.boards.all_access.where(id: board.id)
      elsif super_admin?
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
        redirect_to user_board_path(board.url_user, board), status: :moved_permanently and return
      end
      raise
    end

    def redirect_script_name_board_to_user_path
      redirect_to user_board_path(@board.url_user, @board, script_name: nil), status: :moved_permanently
    end

    def ensure_permission_to_admin_board
      head :forbidden if Current.user.blank?
      head :forbidden unless super_admin? || Current.user.can_administer_board?(@board)
    end

    def grantees_changed?
      params.key?(:user_ids)
    end

    def show_filtered_cards
      @filter.board_ids = [ @board.id ]
      cards_scope = viewing_board_as_limited_viewer? ? @filter.cards.published : @filter.cards
      set_page_and_extract_portion_from cards_scope
    end

    def show_columns
      cards = @board.cards.awaiting_triage.latest.with_golden_first.preloaded
      cards = cards.published if viewing_board_as_limited_viewer?
      set_page_and_extract_portion_from cards
      fresh_when etag: [ @board, @page.records, @user_filtering, Current.account ]
    end

    def viewing_board_as_limited_viewer?
      viewing_other_user_as_limited_viewer? || (viewing_public_board_in_current_account? && Current.user.blank?)
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
