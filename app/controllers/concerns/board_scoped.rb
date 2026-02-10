module BoardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_board
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
    # 含「仅因 @ 提及/指派可见」的看板回退，与 BoardsController 的 find_board_by_mention_fallback 一致
    def find_board_by_fallback
      return unless params[:board_id].present?
      board = Board.find_by(id: params[:board_id])
      return unless board.present?
      return board if Current.account.present? && board.account_id == Current.account.id
      return board if Current.user.present? && board.accessible_to?(Current.user)
      if board.all_access?
        Current.account = board.account if Current.account&.id != board.account_id
        @board_from_public_fallback = true
        return board
      end
      # 身份存在但无当前账号 User 时，允许该身份下任一用户可访问的看板
      if Current.user.blank? && Current.identity.present?
        return board if Current.identity.users.any? { |u| board.accessible_to?(u) }
      end
      # 仅因提及/指派可访问该看板内至少一张卡片时，允许进入看板（受限视图）
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
end
