require "test_helper"

class Webhooks::ActivationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    webhook = webhooks(:inactive)

    assert_not webhook.active?

    assert_changes -> { webhook.reload.active? }, from: false, to: true do
      post user_board_webhook_activation_path(webhook.board.url_user, webhook.board, webhook)
    end

    assert_redirected_to user_board_webhook_path(webhook.board.url_user, webhook.board, webhook)
  end

  test "cannot activate webhook on board without access" do
    logout_and_sign_in_as :jason
    webhook = webhooks(:inactive)  # on private board, jason has no access

    post user_board_webhook_activation_path(webhook.board.url_user, webhook.board, webhook)
    assert_response :not_found
  end

  test "non-admin cannot activate webhook" do
    logout_and_sign_in_as :jz  # member with writebook access, but not admin
    webhook = webhooks(:active)  # on writebook board

    post user_board_webhook_activation_path(webhook.board.url_user, webhook.board, webhook)
    assert_response :forbidden
  end
end
