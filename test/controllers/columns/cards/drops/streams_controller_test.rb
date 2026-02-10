require "test_helper"

class Columns::Cards::Drops::StreamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:text)
    board = card.board

    assert_changes -> { card.reload.triaged? }, from: true, to: false do
      post user_board_columns_card_drops_stream_path(board.url_user, board, card), as: :turbo_stream
      assert_response :success
    end
  end
end
