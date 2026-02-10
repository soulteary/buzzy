require "test_helper"

class Cards::DraftsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    card = boards(:writebook).cards.create!(creator: users(:kevin), status: :drafted)

    get user_board_card_draft_path(card.board.url_user, card.board, card)
    assert_response :success
  end

  test "show redirects to card when published" do
    card = cards(:logo)

    get user_board_card_draft_path(card.board.url_user, card.board, card)
    assert_redirected_to card
  end
end
