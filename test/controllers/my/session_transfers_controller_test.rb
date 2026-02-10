require "test_helper"

class My::SessionTransfersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "update disables session transfer" do
    identity = identities(:kevin)
    assert identity.session_transfer_enabled?

    patch my_session_transfer_path, params: { session_transfer: { enabled: "0" } }

    assert_not identity.reload.session_transfer_enabled?
  end

  test "update returns not_found when session transfer is disabled by env" do
    Buzzy.instance_variable_set(:@session_transfer_enabled, false)

    patch my_session_transfer_path, params: { session_transfer: { enabled: "1" } }

    assert_response :not_found
  ensure
    Buzzy.remove_instance_variable(:@session_transfer_enabled) if Buzzy.instance_variable_defined?(:@session_transfer_enabled)
  end
end
