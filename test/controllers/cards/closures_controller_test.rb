require "test_helper"

class Cards::ClosuresControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)

    assert_changes -> { card.reload.closed? }, from: false, to: true do
      post board_card_closure_path(card.board, card), as: :turbo_stream
      assert_card_container_rerendered(card)
    end
  end

  test "destroy" do
    card = cards(:shipping)

    assert_changes -> { card.reload.closed? }, from: true, to: false do
      delete board_card_closure_path(card.board, card), as: :turbo_stream
      assert_card_container_rerendered(card)
    end
  end

  test "create as JSON" do
    card = cards(:logo)

    assert_not card.closed?

    post board_card_closure_path(card.board, card), as: :json

    assert_response :no_content
    assert card.reload.closed?
  end

  test "destroy as JSON" do
    card = cards(:shipping)

    assert card.closed?

    delete board_card_closure_path(card.board, card), as: :json

    assert_response :no_content
    assert_not card.reload.closed?
  end
end
