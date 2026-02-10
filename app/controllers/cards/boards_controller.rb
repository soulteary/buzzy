class Cards::BoardsController < ApplicationController
  include BoardScoped

  skip_before_action :set_board, only: %i[ edit ]
  before_action :set_card
  before_action :ensure_card_editable, only: %i[ edit update ]

  def edit
    # 仅展示与当前卡片同账户的看板（可放入的看板），来源为「当前账户有权限 + 跨账户公开且已关注」的看板列表
    @boards = Current.user.boards_visible_in_dropdown.select { |b| b.account_id == @card.account_id }
    fresh_when @boards
  end

  def update
    @card.move_to(@board)

    respond_to do |format|
      format.html { redirect_to @card }
      format.json { head :no_content }
    end
  end

  private
    def ensure_card_editable
      return if card_editable_by_current_user?(@card)
      respond_to do |format|
        format.html { redirect_to @card, alert: t("cards.board_change_not_allowed") }
        format.json { head :forbidden }
      end
    end

    def set_card
      profile_user_id = params[:user_id].presence || Current.context_user&.id
      if profile_user_id.present? && params[:board_id].present? && Current.account.present?
        user = Current.account.users.active.find(profile_user_id)
        visible = boards_visible_when_viewing_user(user) || user.boards
        board = visible.where(account_id: Current.account.id).find(params[:board_id])
        scope = board.cards.where(account_id: Current.account.id)
        scope = scope.published if viewing_other_user_as_limited_viewer?
        @card = scope.find_by!(number: params[:card_id] || params[:id])
      else
        @card = Current.user.accessible_cards.find_by!(number: params[:card_id] || params[:id])
      end
    end
end
