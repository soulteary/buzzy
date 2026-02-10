require "test_helper"

class RouteTest < ActionDispatch::IntegrationTest
  test "account/settings" do
    assert_recognizes({ controller: "account/settings", action: "show" }, "/account/settings")
  end

  test "account/entropy" do
    assert_recognizes({ controller: "account/entropies", action: "show" }, "/account/entropy")
  end

  test "user scoped board interaction routes" do
    assert_routing({ method: "put", path: "/users/u1/boards/b1/involvement" }, { controller: "boards/involvements", action: "update", user_id: "u1", board_id: "b1" })
    assert_routing({ method: "put", path: "/users/u1/boards/b1/entropy" }, { controller: "boards/entropies", action: "update", user_id: "u1", board_id: "b1" })
    assert_routing({ method: "post", path: "/users/u1/boards/b1/columns/c1/left_position" }, { controller: "columns/left_positions", action: "create", user_id: "u1", board_id: "b1", column_id: "c1" })
    assert_routing({ method: "post", path: "/users/u1/boards/b1/columns/c1/right_position" }, { controller: "columns/right_positions", action: "create", user_id: "u1", board_id: "b1", column_id: "c1" })
    assert_routing({ method: "post", path: "/users/u1/boards/b1/columns/cards/9/drops/stream" }, { controller: "columns/cards/drops/streams", action: "create", user_id: "u1", board_id: "b1", card_id: "9" })
    assert_routing({ method: "post", path: "/users/u1/boards/b1/columns/cards/9/drops/not_now" }, { controller: "columns/cards/drops/not_nows", action: "create", user_id: "u1", board_id: "b1", card_id: "9" })
    assert_routing({ method: "post", path: "/users/u1/boards/b1/columns/cards/9/drops/closure" }, { controller: "columns/cards/drops/closures", action: "create", user_id: "u1", board_id: "b1", card_id: "9" })
    assert_routing({ method: "post", path: "/users/u1/boards/b1/columns/cards/9/drops/column" }, { controller: "columns/cards/drops/columns", action: "create", user_id: "u1", board_id: "b1", card_id: "9" })
  end
end
