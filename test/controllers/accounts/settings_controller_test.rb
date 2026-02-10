require "test_helper"

class Account::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get account_settings_path
    assert_response :success
  end
end
