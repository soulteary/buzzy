require "test_helper"

class Cards::AssignmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new" do
    card = cards(:logo)
    get new_user_board_card_assignment_path(card.board.url_user, card.board, card)
    assert_response :success
  end

  test "create" do
    card = cards(:logo)
    assert_changes "cards(:logo).reload.assigned_to?(users(:david))", from: false, to: true do
      post user_board_card_assignments_path(card.board.url_user, card.board, card), params: { assignee_id: users(:david).id }, as: :turbo_stream
      assert_meta_replaced(card)
    end

    assert_changes "cards(:logo).reload.assigned_to?(users(:david))", from: true, to: false do
      post user_board_card_assignments_path(card.board.url_user, card.board, card), params: { assignee_id: users(:david).id }, as: :turbo_stream
      assert_meta_replaced(card)
    end
  end

  test "create as JSON" do
    card = cards(:logo)

    assert_not card.assigned_to?(users(:david))

    post user_board_card_assignments_path(card.board.url_user, card.board, card), params: { assignee_id: users(:david).id }, as: :json
    assert_response :no_content
    assert card.reload.assigned_to?(users(:david))

    post user_board_card_assignments_path(card.board.url_user, card.board, card), params: { assignee_id: users(:david).id }, as: :json
    assert_response :no_content
    assert_not card.reload.assigned_to?(users(:david))
  end

  test "member cannot open assignments popup for card they do not administer" do
    logout_and_sign_in_as :jz
    card = cards(:logo)

    get new_user_board_card_assignment_path(card.board.url_user, card.board, card)
    assert_response :forbidden
  end

  test "member cannot assign other users on card they do not administer" do
    logout_and_sign_in_as :jz
    card = cards(:logo)

    post user_board_card_assignments_path(card.board.url_user, card.board, card), params: { assignee_id: users(:david).id }, as: :json
    assert_response :forbidden
    assert_not card.reload.assigned_to?(users(:david))
  end

  private
    def assert_meta_replaced(card)
      assert_turbo_stream action: :replace, target: dom_id(card, :meta)
    end
end
