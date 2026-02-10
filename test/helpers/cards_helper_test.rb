require "test_helper"

class CardsHelperTest < ActionView::TestCase
  include CardsHelper

  test "card path helpers are user scoped" do
    card = cards(:logo)
    comment = comments(:logo_agreement_kevin)
    step = card.steps.create!(content: "test step")

    assert_equal user_board_card_path(card.board.url_user, card.board, card), card_path_with_context(card)
    assert_equal user_board_card_watch_path(card.board.url_user, card.board, card), card_path_with_context(card, :watch)
    assert_equal user_board_card_assignments_path(card.board.url_user, card.board, card), card_assignments_path(card)
    assert_equal user_board_card_comments_path(card.board.url_user, card.board, card), card_comments_path(card)
    assert_equal user_board_card_comment_path(card.board.url_user, card.board, card, comment), card_comment_path(card, comment)
    assert_equal edit_user_board_card_comment_path(card.board.url_user, card.board, card, comment), edit_card_comment_path(card, comment)
    assert_equal user_board_card_step_path(card.board.url_user, card.board, card, step), card_step_path(card, step)
  end
end
