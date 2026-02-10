# frozen_string_literal: true

require "test_helper"

class Users::BoardsControllerTest < ActionDispatch::IntegrationTest
  test "account admin sees all boards when viewing another user" do
    sign_in_as :kevin
    david = users(:david)
    get boards_user_path(david)
    assert_response :success
    visible_ids = assigns(:boards).pluck(:id)
    assert_includes visible_ids, boards(:writebook).id, "Admin should see all of profile user's boards"
  end

  test "non-admin does not see other user's non-public boards" do
    logout_and_sign_in_as :jz
    kevin = users(:kevin)
    assert_includes kevin.boards.pluck(:id), boards(:private).id, "Kevin has private board"
    get boards_user_path(kevin)
    assert_response :success
    visible_ids = assigns(:boards).pluck(:id)
    assert_includes visible_ids, boards(:writebook).id, "JZ should see public writebook"
    assert_not_includes visible_ids, boards(:private).id, "JZ should not see Kevin's private board"
  end
end
