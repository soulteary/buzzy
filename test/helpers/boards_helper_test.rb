require "test_helper"

class BoardsHelperTest < ActionView::TestCase
  test "board scoped path helpers use board url_user" do
    board = boards(:writebook)

    assert_equal user_board_cards_path(board.url_user, board), board_cards_create_path(board)
    assert_equal user_board_involvement_path(board.url_user, board), board_involvement_update_path(board)
    assert_equal user_board_entropy_path(board.url_user, board), board_entropy_update_path(board)
  end
end
