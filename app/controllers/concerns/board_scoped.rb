module BoardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_board
    before_action :redirect_script_name_board_to_user_path, if: -> { request.script_name.present? && @board.present? }
    before_action :ensure_board_editable, only: %i[ create update destroy ]
  end

  private
    def set_board
      scope = board_scope
      begin
        @board = scope.find(params[:board_id]) if scope.present?
      rescue ActiveRecord::RecordNotFound
        @board = nil
      end
      @board ||= find_board_by_fallback
      raise ActiveRecord::RecordNotFound if @board.nil?
    end

    def board_scope
      if super_admin? || Current.user&.admin?
        Current.account&.boards
      elsif Current.user.present?
        Current.account_single_user? ? Current.account.boards : Current.user.boards
      else
        Current.account&.boards&.all_access
      end
    end

    # 跨账号场景：当前身份在 URL 账号下无看板或看板属他账号（如从 prompts @ 提及加载看板用户列表），按 id 查找并校验可访问性
    def find_board_by_fallback
      return unless params[:board_id].present?
      board = Board.find_by(id: params[:board_id])
      return unless board.present?
      return board if Current.account.present? && board.account_id == Current.account.id
      return board if Current.user.present? && board.accessible_to?(Current.user)
      return board if board.all_access?
      # 身份存在但无当前账号 User 时，允许该身份下任一用户可访问的看板
      if Current.user.blank? && Current.identity.present?
        return board if Current.identity.users.any? { |u| board.accessible_to?(u) }
      end
      nil
    end

    def ensure_permission_to_admin_board
      head :forbidden if Current.user.blank?
      head :forbidden unless super_admin? || Current.user.can_administer_board?(@board)
    end

    def redirect_script_name_board_to_user_path
      redirect_to user_board_path(@board.url_user, @board, script_name: nil), status: :moved_permanently
    end
end
