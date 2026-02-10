require "test_helper"

class Cards::ReadingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    freeze_time

    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: false, to: true do
      assert_changes -> { accesses(:writebook_kevin).reload.accessed_at }, from: nil, to: Time.current do
        post user_board_card_reading_url(boards(:writebook).url_user, boards(:writebook), cards(:logo)), as: :turbo_stream
      end
    end

    assert_response :success
  end

  test "read one notification on card visit" do
    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: false, to: true do
      post user_board_card_reading_path(boards(:writebook).url_user, boards(:writebook), cards(:logo)), as: :turbo_stream
    end

    assert_response :success
    assert_includes response.body, "turbo-stream action=\"remove\""
    assert_includes response.body, notifications(:logo_published_kevin).id
  end

  test "read multiple notifications on card visit" do
    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: false, to: true do
      assert_changes -> { notifications(:logo_assignment_kevin).reload.read? }, from: false, to: true do
        post user_board_card_reading_path(boards(:writebook).url_user, boards(:writebook), cards(:logo)), as: :turbo_stream
      end
    end

    assert_response :success
  end

  test "destroy" do
    freeze_time

    notifications(:logo_published_kevin).read
    notifications(:logo_assignment_kevin).read

    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: true, to: false do
      assert_changes -> { accesses(:writebook_kevin).reload.accessed_at }, to: Time.current do
        delete user_board_card_reading_url(boards(:writebook).url_user, boards(:writebook), cards(:logo)), as: :turbo_stream
      end
    end

    assert_response :success
  end

  test "unread one notification on destroy" do
    notifications(:logo_published_kevin).read

    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: true, to: false do
      delete user_board_card_reading_path(boards(:writebook).url_user, boards(:writebook), cards(:logo)), as: :turbo_stream
    end

    assert_response :success
  end

  test "create as JSON returns payload" do
    post user_board_card_reading_path(boards(:writebook).url_user, boards(:writebook), cards(:logo)), as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal true, payload["ok"]
    assert_equal "read", payload["action"]
    assert payload["count"] >= 1
  end

  test "destroy as JSON returns payload" do
    notifications(:logo_published_kevin).read

    delete user_board_card_reading_path(boards(:writebook).url_user, boards(:writebook), cards(:logo)), as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal true, payload["ok"]
    assert_equal "unread", payload["action"]
    assert payload["count"] >= 1
  end

  test "mentioned user can mark hidden-board card as read via reading endpoint" do
    logout_and_sign_in_as :david
    board = boards(:private)
    card = cards(:secret_card)

    post user_board_card_reading_path(board.url_user, board, card), as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal true, payload["ok"]
    assert_equal "read", payload["action"]
  end

  test "unread multiple notifications on destroy" do
    notifications(:logo_published_kevin).read
    notifications(:logo_assignment_kevin).read

    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: true, to: false do
      assert_changes -> { notifications(:logo_assignment_kevin).reload.read? }, from: true, to: false do
        delete user_board_card_reading_path(boards(:writebook).url_user, boards(:writebook), cards(:logo)), as: :turbo_stream
      end
    end

    assert_response :success
  end
end
