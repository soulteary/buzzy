require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    board = boards(:writebook)
    get user_board_webhooks_path(board.url_user, board)
    assert_response :success
  end

  test "show" do
    webhook = webhooks(:active)
    get user_board_webhook_path(webhook.board.url_user, webhook.board, webhook)
    assert_response :success

    webhook = webhooks(:inactive)
    get user_board_webhook_path(webhook.board.url_user, webhook.board, webhook)
    assert_response :success
  end

  test "new" do
    board = boards(:writebook)
    get new_user_board_webhook_path(board.url_user, board)
    assert_response :success
    assert_select "form"
  end

  test "create with valid params" do
    board = boards(:writebook)

    assert_difference "Webhook.count", 1 do
      post user_board_webhooks_path(board.url_user, board), params: {
        webhook: {
          name: "Test Webhook",
          url: "https://example.com/webhook",
          subscribed_actions: [ "", "card_published", "card_closed" ]
        }
      }
    end

    webhook = Webhook.last

    assert_redirected_to user_board_webhook_path(webhook.board.url_user, webhook.board, webhook)
    assert_equal board, webhook.board
    assert_equal "Test Webhook", webhook.name
    assert_equal "https://example.com/webhook", webhook.url
    assert_equal [ "card_published", "card_closed" ], webhook.subscribed_actions
  end

  test "create with invalid params" do
    board = boards(:writebook)
    assert_no_difference "Webhook.count" do
      post user_board_webhooks_path(board.url_user, board), params: {
        webhook: {
          name: "",
          url: "invalid-url"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "edit" do
    webhook = webhooks(:active)
    get edit_user_board_webhook_path(webhook.board.url_user, webhook.board, webhook)
    assert_response :success
    assert_select "form"

    webhook = webhooks(:inactive)
    get edit_user_board_webhook_path(webhook.board.url_user, webhook.board, webhook)
    assert_response :success
    assert_select "form"
  end

  test "update with valid params" do
    webhook = webhooks(:active)
    patch user_board_webhook_path(webhook.board.url_user, webhook.board, webhook), params: {
      webhook: {
        name: "Updated Webhook",
        subscribed_actions: [ "card_published" ]
      }
    }

    webhook.reload

    assert_redirected_to user_board_webhook_path(webhook.board.url_user, webhook.board, webhook)
    assert_equal "Updated Webhook", webhook.name
    assert_equal [ "card_published" ], webhook.subscribed_actions
  end

  test "update with invalid params" do
    webhook = webhooks(:active)
    patch user_board_webhook_path(webhook.board.url_user, webhook.board, webhook), params: {
      webhook: {
        name: ""
      }
    }

    assert_response :unprocessable_entity

    assert_no_changes -> { webhook.reload.url } do
      patch user_board_webhook_path(webhook.board.url_user, webhook.board, webhook), params: {
        webhook: {
          name: "Updated Webhook",
          url: "https://different.com/webhook"
        }
      }
    end

    assert_redirected_to user_board_webhook_path(webhook.board.url_user, webhook.board, webhook)
  end

  test "destroy" do
    webhook = webhooks(:active)

    assert_difference "Webhook.count", -1 do
      delete user_board_webhook_path(webhook.board.url_user, webhook.board, webhook)
    end

    assert_redirected_to user_board_webhooks_path(webhook.board.url_user, webhook.board)
  end

  test "cannot access webhooks on board without access" do
    logout_and_sign_in_as :jason

    webhook = webhooks(:inactive)  # on private board, jason has no access

    get user_board_webhooks_path(webhook.board.url_user, webhook.board)
    assert_response :not_found
  end
end
