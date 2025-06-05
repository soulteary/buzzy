require "test_helper"

class CommandsControllerTest < ActionDispatch::IntegrationTest
  include VcrTestHelper

  setup do
    sign_in_as :kevin
  end

  test "command that results in a redirect" do
    assert_difference -> { users(:kevin).commands.count }, +1 do
      post commands_path, params: { command: "#{cards(:logo).id}" }
    end

    assert_redirected_to cards(:logo)
  end

  test "command that triggers a redirect back" do
    assert_difference -> { users(:kevin).commands.count }, +1 do
      post commands_path, params: { command: "/assign @kevin", confirmed: "confirmed" }, headers: { "HTTP_REFERER" => cards_path }
    end

    assert_redirected_to cards_path
  end

  test "command requiring a confirmation without redirect" do
    assert_no_difference -> { users(:kevin).commands.count } do
      post commands_path, params: { command: "/assign @kevin" }, headers: { "HTTP_REFERER" => cards_path }
    end

    assert_response :conflict

    json = JSON.parse(response.body)
    assert_equal "Assign 3 cards to Kevin", json["confirmation"]
    assert_nil json["redirect_to"]
  end

  test "command requiring a confirmation with a redirect" do
    assert_no_difference -> { users(:kevin).commands.count } do
      post commands_path, params: { command: "close cards assigned to jz" }, headers: { "HTTP_REFERER" => cards_path }
    end

    assert_response :conflict

    json = JSON.parse(response.body)
    assert_match /Close 2 cards/, json["confirmation"]
    assert_equal cards_path(assignee_ids: [users(:jz)]), json["redirect_to"]
  end

  test "get insight" do
    without_vcr_body_matching do
      assert_difference -> { users(:kevin).commands.root.count }, +1 do
        post commands_path, params: { command: "summarize this" }, headers: { "HTTP_REFERER" => card_path(cards(:logo)) }
      end

      assert_response :accepted

      json = JSON.parse(response.body)
      assert_not_nil json["message"]
    end
  end

  test "get a 422 on errors" do
    post commands_path, params: { command: "/assign @some_missing_user" }, headers: { "HTTP_REFERER" => cards_path }
    assert_response :unprocessable_entity
  end
end
