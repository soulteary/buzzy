require "test_helper"

class Boards::ColumnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    board = boards(:writebook)
    column = columns(:writebook_in_progress)
    get user_board_column_path(board.url_user, board, column)
    assert_response :success
  end

  test "create" do
    board = boards(:writebook)
    assert_difference -> { board.columns.count }, +1 do
      post user_board_columns_path(board.url_user, board), params: { column: { name: "New Column" } }, as: :turbo_stream
      assert_response :success
    end

    assert_equal "New Column", board.columns.last.name
  end

  test "create refreshes adjacent columns" do
    board = boards(:writebook)

    post user_board_columns_path(board.url_user, board), params: { column: { name: "New Column" } }, as: :turbo_stream

    new_column = board.columns.find_by!(name: "New Column")
    new_column.adjacent_columns.each do |adjacent_column|
      assert_turbo_stream action: :replace, target: dom_id(adjacent_column)
    end
  end

  test "update" do
    board = boards(:writebook)
    column = columns(:writebook_in_progress)

    assert_changes -> { column.reload.name }, from: "In progress", to: "Updated Name" do
      put user_board_column_path(board.url_user, board, column), params: { column: { name: "Updated Name" } }, as: :turbo_stream
      assert_response :success
    end
  end

  test "destroy" do
    column = columns(:writebook_in_progress)

    delete user_board_column_path(column.board.url_user, column.board, column), as: :turbo_stream

    assert_redirected_to column.board
  end

  test "index as JSON" do
    board = boards(:writebook)

    get user_board_columns_path(board.url_user, board), as: :json

    assert_response :success
    assert_equal board.columns.count, @response.parsed_body.count
  end

  test "show as JSON" do
    column = columns(:writebook_in_progress)

    get user_board_column_path(column.board.url_user, column.board, column), as: :json

    assert_response :success
    assert_equal column.id, @response.parsed_body["id"]
  end

  test "create as JSON" do
    board = boards(:writebook)

    assert_difference -> { board.columns.count }, +1 do
      post user_board_columns_path(board.url_user, board), params: { column: { name: "New Column" } }, as: :json
    end

    assert_response :created
    assert_equal user_board_column_path(board.url_user, board, Column.last, format: :json), @response.headers["Location"]
  end

  test "update as JSON" do
    column = columns(:writebook_in_progress)

    put user_board_column_path(column.board.url_user, column.board, column), params: { column: { name: "Updated Name" } }, as: :json

    assert_response :no_content
    assert_equal "Updated Name", column.reload.name
  end

  test "destroy as JSON" do
    column = columns(:writebook_on_hold)

    assert_difference -> { column.board.columns.count }, -1 do
      delete user_board_column_path(column.board.url_user, column.board, column), as: :json
    end

    assert_response :no_content
  end
end
