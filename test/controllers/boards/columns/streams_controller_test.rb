require "test_helper"

class Boards::Columns::StreamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get user_board_columns_stream_path(boards(:writebook).url_user, boards(:writebook))
    assert_response :success
  end
end
