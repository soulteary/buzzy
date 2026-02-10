require "test_helper"

class BoardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new" do
    get new_board_path
    assert_response :success
  end

  test "show" do
    board = boards(:writebook)
    get user_board_path(board.url_user, board)
    assert_response :success
  end

  test "invalidates page title cache when account updates" do
    board = boards(:writebook)
    get user_board_path(board.url_user, board)
    etag = response.headers["ETag"]

    accounts("37s").update!(name: "Renamed Account")

    get user_board_path(board.url_user, board), headers: { "If-None-Match" => etag }
    assert_response :success
  end

  test "create" do
    assert_difference -> { Board.count }, +1 do
      post boards_path, params: { board: { name: "Remodel Punch List" } }
    end

    board = Board.last
    assert_redirected_to user_board_path(board.url_user, board)
    assert_includes board.users, users(:kevin)
    assert_equal "Remodel Punch List", board.name
  end

  test "edit" do
    # writebook 的创建者是 david，仅创建者可访问设置页
    board = boards(:writebook)
    logout_and_sign_in_as :david
    get edit_user_board_path(board.url_user, board)
    assert_response :success
  end

  test "update" do
    # writebook 创建者为 david，仅创建者可更新
    board = boards(:writebook)
    logout_and_sign_in_as :david
    patch user_board_path(board.url_user, board), params: {
      board: {
        name: "Writebook bugs",
        all_access: false,
        auto_postpone_period: 1.day
      },
      user_ids: users(:david, :jz).pluck(:id)
    }

    assert_redirected_to edit_user_board_path(board.url_user, board)
    assert_equal "Writebook bugs", boards(:writebook).reload.name
    assert_equal users(:david, :jz).sort, boards(:writebook).users.sort
    assert_equal 1.day, entropies(:writebook_board).auto_postpone_period
    assert_not boards(:writebook).all_access?
  end

  test "update redirects to root when user removes themselves from board" do
    board = boards(:writebook)
    logout_and_sign_in_as :david

    patch user_board_path(board.url_user, board), params: {
      board: { name: "Updated name", all_access: false },
      user_ids: users(:jz).pluck(:id)
    }

    assert_redirected_to root_path
    assert_not board.reload.users.include?(users(:david))
  end

  test "update board with granular permissions, submitting no user ids" do
    board = boards(:private)
    assert_not board.all_access?

    board.users = [ users(:kevin) ]
    board.save!

    patch user_board_path(board.url_user, board), params: {
      board: { name: "Renamed" }
    }

    assert_redirected_to edit_user_board_path(board.url_user, board)
    assert_equal "Renamed", boards(:private).reload.name
    assert_equal [ users(:kevin) ], boards(:private).users
    assert_not boards(:private).all_access?
  end

  test "update all access" do
    board = Current.set(account: accounts("37s"), session: sessions(:kevin), user: users(:kevin)) do
      Board.create! name: "New board", all_access: false
    end
    assert_equal [ users(:kevin) ], board.users

    patch user_board_path(board.url_user, board), params: { board: { name: "Bugs", all_access: true } }

    assert_redirected_to edit_user_board_path(board.url_user, board)
    assert board.reload.all_access?
    assert_equal accounts("37s").users.active.sort, board.users.sort
  end

  test "destroy" do
    board = boards(:writebook)
    logout_and_sign_in_as :david
    delete user_board_path(board.url_user, board)
    assert_redirected_to root_path
    assert_raises(ActiveRecord::RecordNotFound) { board.reload }
  end

  test "non-admin cannot change all_access on board they don't own" do
    logout_and_sign_in_as :jz

    board = boards(:writebook)
    original_all_access = board.all_access

    patch user_board_path(board.url_user, board), params: { board: { all_access: !original_all_access } }

    assert_response :forbidden
    assert_equal original_all_access, board.reload.all_access
  end

  test "non-admin cannot change individual user accesses on board they don't own" do
    logout_and_sign_in_as :jz

    board = boards(:writebook)
    original_users = board.users.sort

    patch user_board_path(board.url_user, board), params: {
      board: { name: board.name },
      user_ids: [ users(:jz).id ]
    }

    assert_response :forbidden
    assert_equal original_users, board.reload.users.sort
  end

  test "non-admin cannot change board name on board they don't own" do
    logout_and_sign_in_as :jz

    board = boards(:writebook)
    original_name = board.name

    patch user_board_path(board.url_user, board), params: {
      board: { name: "Hacked Board Name" }
    }

    assert_response :forbidden
    assert_equal original_name, board.reload.name
  end

  test "non-admin cannot destroy board they don't own" do
    logout_and_sign_in_as :jz

    board = boards(:writebook)
    delete user_board_path(board.url_user, board)

    assert_response :forbidden
  end

  test "disables select all/none buttons for non-privileged user" do
    board = boards(:writebook)
    logout_and_sign_in_as :jz
    assert_not users(:jz).can_administer_board?(board)

    get edit_user_board_path(board.url_user, board)

    assert_response :forbidden
  end

  test "enables select all/none buttons for privileged user" do
    board = boards(:writebook)
    logout_and_sign_in_as :david
    assert users(:david).can_administer_board?(board)

    get edit_user_board_path(board.url_user, board)

    assert_response :success
    assert_select "button:not([disabled])", text: "Select all"
    assert_select "button:not([disabled])", text: "Select none"
  end

  test "access toggle disabled state is cached correctly" do
    board = boards(:writebook)
    david = users(:david)

    with_actionview_partial_caching do
      # 创建者（有权限）
      assert users(:david).can_administer_board?(board)
      logout_and_sign_in_as :david

      get edit_user_board_path(board.url_user, board)

      assert_response :success
      assert_select "input.switch__input[name='user_ids[]'][value='#{david.id}']:not([disabled])"

      # 非创建者（无权限，无法打开设置页）
      logout_and_sign_in_as :jz
      assert_not users(:jz).can_administer_board?(board)

      get edit_user_board_path(board.url_user, board)

      assert_response :forbidden
    end
  end

  test "index as JSON" do
    get boards_path, as: :json
    assert_response :success
    assert_equal users(:kevin).boards.count, @response.parsed_body.count
  end

  test "show as JSON" do
    board = boards(:writebook)
    get user_board_path(board.url_user, board), as: :json
    assert_response :success
    assert_equal board.name, @response.parsed_body["name"]
  end

  test "create as JSON" do
    assert_difference -> { Board.count }, +1 do
      post boards_path, params: { board: { name: "My new board" } }, as: :json
    end

    board = Board.last
    assert_response :created
    assert_equal user_board_path(board.url_user, board, format: :json), @response.headers["Location"]
  end

  test "update as JSON" do
    board = boards(:writebook)
    logout_and_sign_in_as :david

    put user_board_path(board.url_user, board), params: { board: { name: "Updated Name" } }, as: :json

    assert_response :no_content
    assert_equal "Updated Name", board.reload.name
  end

  test "destroy as JSON" do
    board = boards(:writebook)
    logout_and_sign_in_as :david

    assert_difference -> { Board.count }, -1 do
      delete user_board_path(board.url_user, board), as: :json
    end

    assert_response :no_content
  end
end
