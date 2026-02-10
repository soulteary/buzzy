require "test_helper"

class QrCodesControllerTest < ActionDispatch::IntegrationTest
  test "show" do
    url = root_url(host: "app.buzzy.example.com")
    signed_token = QrCodeLink.new(url).signed

    get qr_code_path(signed_token)

    assert_response :success
    assert_match %r{image/svg\+xml}, response.content_type
    assert_includes response.body, "<svg"
  end
end
