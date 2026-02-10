class LandingsController < ApplicationController
  def show
    flash.keep(:welcome_letter)

    boards = Current.account_single_user? ? Current.account.boards : Current.user.boards
    if boards.one?
      board = boards.first
      redirect_to user_board_path(board.url_user, board)
    else
      redirect_to root_path
    end
  end
end
