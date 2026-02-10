require "test_helper"

class Prompts::Boards::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
  end

  test "index" do
    get prompts_board_users_path(@board)
    assert_response :success
    assert_select "lexxy-prompt-item", count: 5
    assert_select "lexxy-prompt-item[search*='Mike']", count: 1
    assert_select "lexxy-prompt-item[data-user-id]", count: 5
    assert_select "lexxy-prompt-item[data-account-name='Initech LLC']", count: 1
  end

  test "index excludes inactive users" do
    get prompts_board_users_path(@board)
    assert_response :success
    assert_select "lexxy-prompt-item[search*='David']", count: 1
    assert_select "lexxy-prompt-item[search*='Mike']", count: 1

    users(:david).update!(active: false)

    get prompts_board_users_path(@board)
    assert_response :success
    assert_select "lexxy-prompt-item[search*='David']", count: 0
    assert_select "lexxy-prompt-item[search*='Mike']", count: 1
  end

  test "index with card_id still uses global active users for mentions" do
    card = cards(:logo)
    get prompts_board_users_path(@board, card_id: card.id)
    assert_response :success
    assert_select "lexxy-prompt-item", count: 5
    assert_select "lexxy-prompt-item[search*='Mike']", count: 1
  end

  test "index with invalid card_id still returns global active users" do
    get prompts_board_users_path(@board, card_id: "00000000-0000-0000-0000-000000000000")
    assert_response :success
    assert_select "lexxy-prompt-item", count: 5
    assert_select "lexxy-prompt-item[search*='Mike']", count: 1
  end
end
