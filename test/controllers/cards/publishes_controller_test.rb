require "test_helper"

class Cards::PublishesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)
    card.drafted!

    assert_changes -> { card.reload.published? }, from: false, to: true do
      post user_board_card_publish_path(card.board.url_user, card.board, card)
    end

    assert_redirected_to card.board
  end

  test "create and add another" do
    card = cards(:logo)
    card.drafted!

    assert_changes -> { card.reload.published? }, from: false, to: true do
      assert_difference -> { Card.count }, +1 do
        post user_board_card_publish_path(card.board.url_user, card.board, card, creation_type: "add_another")
      end
    end

    new_card = Card.last
    assert new_card.drafted?
    assert_redirected_to user_board_card_draft_path(new_card.board.url_user, new_card.board, new_card)
  end
end
