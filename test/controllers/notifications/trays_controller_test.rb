require "test_helper"

class Notifications::TraysControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get tray_notifications_path

    assert_response :success
    assert_select "div", text: /Layout is broken/
  end
end
