require "test_helper"

class Cards::TriagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)
    original_column = card.column
    column = columns(:writebook_in_progress)

    assert_changes -> { card.reload.column }, from: original_column, to: column do
      post user_board_card_triage_path(card.board.url_user, card.board, card, column_id: column.id)
      assert_redirected_to user_board_card_path(card.board.url_user, card.board, card)
    end
  end

  test "destroy" do
    card = cards(:shipping)

    assert_changes -> { card.reload.column }, to: nil do
      delete user_board_card_triage_path(card.board.url_user, card.board, card), as: :turbo_stream
      assert_redirected_to user_board_card_path(card.board.url_user, card.board, card)
    end
  end

  test "create as JSON" do
    card = cards(:logo)
    column = columns(:writebook_in_progress)

    post user_board_card_triage_path(card.board.url_user, card.board, card, column_id: column.id), as: :json

    assert_response :no_content
    assert_equal column, card.reload.column
  end

  test "destroy as JSON" do
    card = cards(:shipping)

    assert card.column.present?

    delete user_board_card_triage_path(card.board.url_user, card.board, card), as: :json

    assert_response :no_content
    assert_nil card.reload.column
  end
end
