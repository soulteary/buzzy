class Prompts::Boards::UsersController < ApplicationController
  include BoardScoped

  def index
    # 与「指派任务」一致：有 card 时用 assignable_for_card（管理员/创建者见全部活跃用户，否则仅看板用户）
    if params[:card_id].present?
      card = @board.cards.find_by(id: params[:card_id])
      @users = card ? User.assignable_for_card(card).alphabetically : @board.users.active.alphabetically
    else
      @users = @board.users.active.alphabetically
    end

    if stale? etag: @users
      render layout: false
    end
  end
end
