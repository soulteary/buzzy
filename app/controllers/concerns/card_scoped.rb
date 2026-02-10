module CardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_board, :set_card
    before_action :ensure_board_visible_to_limited_viewer
    before_action :ensure_card_belongs_to_board, if: -> { params[:board_id].present? }
    before_action :ensure_board_editable, only: %i[ create update destroy ]
    before_action :ensure_not_mention_only_access, only: %i[ create update destroy ]
  end

  private
    def set_board
      profile_user_id = params[:user_id].presence || Current.context_user&.id
      if params[:board_id].present? && super_admin?
        @board = Board.find_by(id: params[:board_id])
        Current.account = @board.account if @board.present? && Current.account&.id != @board.account_id
      elsif params[:board_id].present? && profile_user_id.present? && Current.account.present?
        # 用户路径：从对应用户的可见看板查找（与「查看他人」一致）
        user = Current.account.users.active.find_by(id: profile_user_id)
        if user.present?
          visible = boards_visible_when_viewing_user(user) || user.boards
          @board = visible.where(account_id: Current.account.id).find_by(id: params[:board_id])
          return if @board.present?
        end
        @board = find_board_for_cross_account_or_mention
      elsif params[:board_id].present? && Current.account.present?
        @board = find_board_for_cross_account_or_mention
      elsif params[:board_id].present?
        raise ActiveRecord::RecordNotFound
      else
        @board = @card&.board
      end

      raise ActiveRecord::RecordNotFound if params[:board_id].present? && @board.blank?
    end

    def set_card
      card_identifier = params[:card_id] || params[:id]
      if @board.present?
        # 与 CardsController 一致：从看板按账号与 number 查卡，不要求 accessible_cards，以支持「查看他人看板」时懒加载 frame 正常返回
        # 无 Current.account 时（如无 user_id 的 reading 请求）直接按 number 查，避免 NoMethodError
        # 因 @ 提及进入时仅允许该用户通过提及/指派可见的已发布卡片
        if @board_accessed_via_mention && Current.user.present?
          scope = Current.user.cards_visible_in_board_for_limited_view(@board).published
          @card = scope.find_by(number: card_identifier)
          if @card.blank?
            candidate = @board.cards.published.find_by(number: card_identifier)
            @card = candidate if candidate.present? && card_accessible_via_direct_share?(Current.user, candidate, @board.account)
          end
          raise ActiveRecord::RecordNotFound if @card.blank?
        else
          scope = Current.account.present? ? @board.cards.where(account_id: Current.account.id) : @board.cards
          scope = scope.published if viewing_other_user_as_limited_viewer?
          @card = scope.find_by!(number: card_identifier)
        end
      else
        # 无 board_id 时（如 namespace :columns 的 /columns/cards/:id）：path 可能传 card.id，先按 number 再按 id 查
        scope = Current.user.accessible_cards
        @card = scope.find_by(number: card_identifier) || scope.find_by(id: card_identifier)
        raise ActiveRecord::RecordNotFound if @card.nil?
        @board ||= @card.board
      end
    end

    def ensure_card_belongs_to_board
      raise ActiveRecord::RecordNotFound unless @card.board_id == @board.id
    end

    def find_board_for_cross_account_or_mention
      board = Board.find_by(id: params[:board_id])
      return nil if board.blank?

      if board.all_access?
        Current.account = board.account if Current.account&.id != board.account_id
        @board_from_public_fallback = true
        return board
      end

      # 身份存在但当前账号下无 user 时，优先尝试身份下任一用户对该看板的直接访问权限。
      # 这与 BoardScoped 的回退策略保持一致，避免在跨账号 URL 下误判为 404。
      if Current.identity.present?
        board_user = Current.identity.users.find { |u| board.accessible_to?(u) }
        if board_user.present?
          Current.user_before_fallback = Current.user
          Current.user = board_user
          Current.account = board.account
          return board
        end
      end
      return nil if Current.identity.blank?

      # 仅按看板+编号定位卡片，避免账号字段不一致导致提及/指派回退失败。
      card = board.cards.published.find_by(number: card_identifier_param)
      return nil if card.blank?

      account_scope = board.account

      if card_accessible_via_direct_share?(Current.user, card, account_scope)
        Current.account = account_scope if Current.account&.id != account_scope.id
        @board_accessed_via_mention = true
        return board
      end

      mention_user = Current.identity.users.find { |u| card_accessible_via_direct_share?(u, card, account_scope) }
      return nil if mention_user.blank?

      Current.user_before_fallback = Current.user
      Current.user = mention_user
      Current.account = account_scope
      @board_accessed_via_mention = true
      board
    end

    def card_identifier_param
      params[:card_id] || params[:id]
    end

    def card_accessible_via_direct_share?(user, card, account_scope)
      return false if user.blank? || card.blank?

      user.cards_accessible_via_mention(account_scope).exists?(id: card.id) ||
        user.cards_accessible_via_assignment(account_scope).exists?(id: card.id) ||
        user.notified_of_card?(card)
    end

    # 跨账号评论时 Current.account 已由 set_board 回退设为看板所属账号，但当前身份可能仅在其他账号有 User；
    # 在此补全 Current.user（先看板账号下的用户，再被 @ 提及可访问该卡片的身份用户，再仅通过 all_access 可访问时取身份下任一用户），否则 create 会因 creator 为空或后续校验失败。
    def set_user_for_cross_account_comment
      return if Current.user.present?
      return if Current.identity.blank? || @board.blank? || @card.blank?

      source = nil
      Current.user = Current.identity.users.find_by(account: Current.account)
      source = :account_user if Current.user.present?
      unless Current.user.present?
        Current.user = Current.identity.users.find do |u|
          u.cards_accessible_via_mention(Current.account).exists?(id: @card.id) ||
            u.cards_accessible_via_assignment(Current.account).exists?(id: @card.id)
        end
        source = :mention_user if Current.user.present?
      end
      unless Current.user.present?
        Current.user = Current.identity.users.first if @board.all_access?
        source = :all_access_fallback if Current.user.present?
      end
      if Rails.env.development?
        Rails.logger.debug "[CardScoped set_user_for_cross_account_comment] board_id=#{@board.id} card_id=#{@card.id} source=#{source || 'none'} user_id=#{Current.user&.id} forbidden=#{Current.user.blank?}"
      end
      head :forbidden if Current.user.blank?
    end

    # 仅因 @ 提及可访问时不允许修改卡片及子资源（评论除外，由 CommentsController skip）；跨账号用户也不能修改其他账号的卡片
    def ensure_not_mention_only_access
      return if super_admin?
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
        cards = board_display_cards.awaiting_triage.latest.with_golden_first.preloaded
        cards = cards.published if viewing_other_user_as_limited_viewer? && !@board_accessed_via_mention
        set_page_and_extract_portion_from cards
      end
    end
end
