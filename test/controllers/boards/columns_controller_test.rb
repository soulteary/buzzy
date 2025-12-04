require "test_helper"

class Boards::ColumnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get board_column_path(boards(:writebook), columns(:writebook_in_progress))
    assert_response :success
  end

  test "create" do
    assert_difference -> { boards(:writebook).columns.count }, +1 do
      post board_columns_path(boards(:writebook)), params: { column: { name: "New Column" } }, as: :turbo_stream
      assert_response :success
    end

    assert_equal "New Column", boards(:writebook).columns.last.name
  end

  test "update" do
    column = columns(:writebook_in_progress)

    assert_changes -> { column.reload.name }, from: "In progress", to: "Updated Name" do
      put board_column_path(boards(:writebook), column), params: { column: { name: "Updated Name" } }, as: :turbo_stream
      assert_response :success
    end
  end

  test "destroy" do
    column = columns(:writebook_on_hold)

    assert_difference -> { boards(:writebook).columns.count }, -1 do
      delete board_column_path(boards(:writebook), column), as: :turbo_stream
      assert_response :success
    end
  end

  test "create requires board admin permission" do
    logout_and_sign_in_as :jz

    assert_no_difference -> { boards(:writebook).columns.count } do
      post board_columns_path(boards(:writebook)), params: { column: { name: "New Column" } }, as: :turbo_stream
      assert_response :forbidden
    end
  end

  test "update requires board admin permission" do
    logout_and_sign_in_as :jz

    column = columns(:writebook_in_progress)
    original_name = column.name

    put board_column_path(boards(:writebook), column), params: { column: { name: "Updated Name" } }, as: :turbo_stream

    assert_response :forbidden
    assert_equal original_name, column.reload.name
  end

  test "destroy requires board admin permission" do
    logout_and_sign_in_as :jz

    column = columns(:writebook_on_hold)

    assert_no_difference -> { boards(:writebook).columns.count } do
      delete board_column_path(boards(:writebook), column), as: :turbo_stream
      assert_response :forbidden
    end
  end

  test "board creator can manage columns" do
    logout_and_sign_in_as :david  # David is not admin but created writebook board

    assert_difference -> { boards(:writebook).columns.count }, +1 do
      post board_columns_path(boards(:writebook)), params: { column: { name: "Creator Column" } }, as: :turbo_stream
      assert_response :success
    end
  end
end
