require "test_helper"

class Prompts::Boards::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
  end

  test "index" do
    get prompts_board_users_path(@board)
    assert_response :success
    assert_select "lexxy-prompt-item", count: 3
  end

  test "index excludes inactive users" do
    get prompts_board_users_path(@board)
    assert_response :success
    assert_select "lexxy-prompt-item[search*='David']", count: 1

    users(:david).update!(active: false)

    get prompts_board_users_path(@board)
    assert_response :success
    assert_select "lexxy-prompt-item[search*='David']", count: 0
  end

  test "index with card_id uses assignable_for_card (same list as assign task)" do
    card = cards(:logo)
    get prompts_board_users_path(@board, card_id: card.id)
    assert_response :success
    # Kevin is admin, assignable_for_card returns all active account users
    assert_select "lexxy-prompt-item", minimum: 3
  end

  test "index with invalid card_id falls back to board users" do
    get prompts_board_users_path(@board, card_id: "00000000-0000-0000-0000-000000000000")
    assert_response :success
    assert_select "lexxy-prompt-item", count: 3
  end
end
