require "test_helper"

class BlockSearchEngineIndexingTest < ActionDispatch::IntegrationTest
  test "sets X-Robots-Tag header to none on authenticated requests" do
    sign_in_as :david

    get user_board_path(boards(:writebook).url_user, boards(:writebook))
    assert_response :success
    assert_equal "none", response.headers["X-Robots-Tag"]
  end

  test "sets X-Robots-Tag header to none on unauthenticated requests" do
    untenanted do
      get new_session_path
    end

    assert_response :success
    assert_equal "none", response.headers["X-Robots-Tag"]
  end
end
