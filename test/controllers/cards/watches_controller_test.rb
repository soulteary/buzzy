require "test_helper"

class Cards::WatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    cards(:logo).unwatch_by users(:kevin)

    assert_changes -> { cards(:logo).watched_by?(users(:kevin)) }, from: false, to: true do
      post board_card_watch_path(cards(:logo).board, cards(:logo)), as: :turbo_stream
    end
  end

  test "destroy" do
    cards(:logo).watch_by users(:kevin)

    assert_changes -> { cards(:logo).watched_by?(users(:kevin)) }, from: true, to: false do
      delete board_card_watch_path(cards(:logo).board, cards(:logo)), as: :turbo_stream
    end
  end

  test "create as JSON" do
    card = cards(:logo)
    card.unwatch_by users(:kevin)

    assert_not card.watched_by?(users(:kevin))

    post board_card_watch_path(card.board, card), as: :json

    assert_response :no_content
    assert card.reload.watched_by?(users(:kevin))
  end

  test "destroy as JSON" do
    card = cards(:logo)
    card.watch_by users(:kevin)

    assert card.watched_by?(users(:kevin))

    delete board_card_watch_path(card.board, card), as: :json

    assert_response :no_content
    assert_not card.reload.watched_by?(users(:kevin))
  end
end
