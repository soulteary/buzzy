require "test_helper"

class Sessions::TransfersControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Session transfer is disabled when Forward Auth is enabled; ensure we test the non-FA path
    Rails.application.config.forward_auth = ForwardAuth::Config.new(enabled: false)
  end

  test "show renders when not signed in" do
    untenanted do
      get session_transfer_path("some-token")

      assert_response :success
    end
  end

  test "update establishes a session when the code is valid" do
    identity = identities(:david)

    untenanted do
      put session_transfer_path(identity.transfer_id)

      assert_redirected_to session_menu_url(script_name: nil)
      assert parsed_cookies.signed[:session_token]
    end
  end

  test "update rejects disabled transfer links" do
    identity = identities(:david)
    transfer_id = identity.transfer_id
    identity.update!(session_transfer_enabled: false)

    untenanted do
      put session_transfer_path(transfer_id)

      assert_response :bad_request
      assert_nil parsed_cookies.signed[:session_token]
    end
  end

  test "update returns bad_request when session transfer is disabled by env" do
    identity = identities(:david)
    transfer_id = identity.transfer_id
    Buzzy.instance_variable_set(:@session_transfer_enabled, false)

    untenanted do
      put session_transfer_path(transfer_id)

      assert_response :bad_request
      assert_nil parsed_cookies.signed[:session_token]
    end
  ensure
    Buzzy.remove_instance_variable(:@session_transfer_enabled) if Buzzy.instance_variable_defined?(:@session_transfer_enabled)
  end
end
