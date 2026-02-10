require "test_helper"

class Columns::Cards::Drops::ClosuresControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)
    board = card.board

    assert_changes -> { card.reload.closed? }, from: false, to: true do
      post user_board_columns_card_drops_closure_path(board.url_user, board, card), as: :turbo_stream
      assert_response :success
    end
  end
end
