module CardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_board, :set_card
    before_action :redirect_script_name_to_user_path, if: :script_name_present_with_board_and_card?
    before_action :ensure_board_visible_to_limited_viewer
    before_action :ensure_card_belongs_to_board, if: -> { params[:board_id].present? }
    before_action :ensure_board_editable, only: %i[ create update destroy ]
    before_action :ensure_not_mention_only_access, only: %i[ create update destroy ]
  end

  private
    def set_board
      profile_user_id = params[:user_id].presence || Current.context_user&.id
      if params[:board_id].present? && profile_user_id.present? && Current.account.present?
        # 用户路径：从对应用户的可见看板查找（与「查看他人」一致）
        user = Current.account.users.active.find(profile_user_id)
        visible = boards_visible_when_viewing_user(user) || user.boards
        @board = visible.where(account_id: Current.account.id).find(params[:board_id])
      elsif params[:board_id].present? && request.script_name.present? && Current.account.present?
        # 仅用于 301：旧链接 /:script_name/boards/:id/... 从当前账号查看板后重定向到 user 路径
        @board = Current.account.boards.find(params[:board_id])
      elsif params[:board_id].present?
        raise ActiveRecord::RecordNotFound
      else
        @board = @card&.board
      end
    end

    def set_card
      card_identifier = params[:card_id] || params[:id]
      if @board.present?
        # 与 CardsController 一致：从看板按账号与 number 查卡，不要求 accessible_cards，以支持「查看他人看板」时懒加载 frame 正常返回
        # 无 Current.account 时（如无 user_id 的 reading 请求）直接按 number 查，避免 NoMethodError
        # 因 @ 提及进入时仅允许已发布卡片
        scope = Current.account.present? ? @board.cards.where(account_id: Current.account.id) : @board.cards
        scope = scope.published if viewing_other_user_as_limited_viewer?
        @card = scope.find_by!(number: card_identifier)
      else
        # 无 board_id 时（如 namespace :columns 的 /columns/cards/:id）：path 可能传 card.id，先按 number 再按 id 查
        scope = Current.user.accessible_cards
        @card = scope.find_by(number: card_identifier) || scope.find_by(id: card_identifier)
        raise ActiveRecord::RecordNotFound if @card.nil?
        @board ||= @card.board
      end
    end

    def script_name_present_with_board_and_card?
      request.script_name.present? && @board.present? && @card.present?
    end

    def redirect_script_name_to_user_path
      redirect_to user_board_card_path(@board.url_user, @board, @card, script_name: nil), status: :moved_permanently
    end

    def ensure_card_belongs_to_board
      raise ActiveRecord::RecordNotFound unless @card.board_id == @board.id
    end

    # 跨账号评论时 Current.account 已由 set_board 回退设为看板所属账号，但当前身份可能仅在其他账号有 User；
    # 在此补全 Current.user（先看板账号下的用户，再被 @ 提及可访问该卡片的身份用户，再仅通过 all_access 可访问时取身份下任一用户），否则 create 会因 creator 为空或后续校验失败。
    def set_user_for_cross_account_comment
      return if Current.user.present?
      return if Current.identity.blank? || @board.blank? || @card.blank?

      Current.user = Current.identity.users.find_by(account: Current.account)
      Current.user ||= Current.identity.users.find { |u| u.cards_accessible_via_mention(Current.account).exists?(id: @card.id) }
      Current.user ||= Current.identity.users.first if @board.all_access?
      head :forbidden if Current.user.blank?
    end

    # 仅因 @ 提及可访问时不允许修改卡片及子资源（评论除外，由 CommentsController skip）；跨账号用户也不能修改其他账号的卡片
    def ensure_not_mention_only_access
      head :forbidden if @board_accessed_via_mention || card_from_other_account?
    end

    def render_card_replacement
      render turbo_stream: turbo_stream.replace([ @card, :card_container ], partial: "cards/container", method: :morph, locals: { card: @card.reload })
    end

    def capture_card_location
      @source_column = @card.column
      @was_in_stream = @card.awaiting_triage?
    end

    def refresh_stream_if_needed
      if @was_in_stream
        cards = @board.cards.awaiting_triage.latest.with_golden_first.preloaded
        cards = cards.published if viewing_other_user_as_limited_viewer?
        set_page_and_extract_portion_from cards
      end
    end
end
