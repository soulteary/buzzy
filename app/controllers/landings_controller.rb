class LandingsController < ApplicationController
  def show
    flash.keep(:welcome_letter)

    # 新用户首次进入：若账户尚无看板（未执行过 populate 教程），则补跑一次，确保演练场与教程卡片存在
    if account_single_user? && Current.account.boards.empty?
      Current.account.setup_customer_template
    end

    boards = Current.account_single_user? ? Current.account.boards : Current.user.boards
    if boards.one?
      board = boards.first
      redirect_to user_board_path(board.url_user, board)
    else
      redirect_to root_path
    end
  end
end
