require "test_helper"

class Columns::Cards::Drops::ColumnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)
    board = card.board
    column = columns(:writebook_in_progress)

    assert_changes -> { card.reload.column }, to: column do
      post user_board_columns_card_drops_column_path(board.url_user, board, card, column_id: column.id), as: :turbo_stream
      assert_response :success
    end
  end
end
