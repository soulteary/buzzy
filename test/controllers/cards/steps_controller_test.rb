require "test_helper"

class Cards::StepsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)

    assert_difference -> { card.steps.count }, +1 do
      post user_board_card_steps_path(card.board.url_user, card.board, card), params: { step: { content: "Research alternatives" } }, as: :turbo_stream
      assert_turbo_stream action: :before, target: dom_id(card, :new_step)
    end

    assert_equal "Research alternatives", card.steps.last.content
  end

  test "update" do
    card = cards(:logo)
    step = card.steps.create!(content: "Original content")

    assert_changes -> { step.reload.content }, from: "Original content", to: "Updated content" do
      put user_board_card_step_path(card.board.url_user, card.board, card, step), params: { step: { content: "Updated content" } }, as: :turbo_stream
      assert_turbo_stream action: :replace, target: dom_id(step)
    end
  end

  test "destroy" do
    card = cards(:logo)
    step = card.steps.create!(content: "Step to delete")

    assert_difference -> { card.steps.count }, -1 do
      delete user_board_card_step_path(card.board.url_user, card.board, card, step), as: :turbo_stream
      assert_turbo_stream action: :remove, target: dom_id(step)
    end
  end

  test "toggle completion" do
    card = cards(:logo)
    step = card.steps.create!(content: "Test step", completed: false)

    # Toggle to completed
    assert_changes -> { step.reload.completed? }, from: false, to: true do
      put user_board_card_step_path(card.board.url_user, card.board, card, step), params: { step: { completed: "1" } }, as: :turbo_stream
      assert_turbo_stream action: :replace, target: dom_id(step)
    end

    # Toggle back to incomplete
    assert_changes -> { step.reload.completed? }, from: true, to: false do
      put user_board_card_step_path(card.board.url_user, card.board, card, step), params: { step: { completed: "0" } }, as: :turbo_stream
      assert_turbo_stream action: :replace, target: dom_id(step)
    end
  end

  test "create as JSON" do
    card = cards(:logo)

    assert_difference -> { card.steps.count }, +1 do
      post user_board_card_steps_path(card.board.url_user, card.board, card), params: { step: { content: "New step" } }, as: :json
    end

    assert_response :created
    assert_equal user_board_card_step_path(card.board.url_user, card.board, card, Step.last, format: :json), @response.headers["Location"]
  end

  test "show as JSON" do
    card = cards(:logo)
    step = card.steps.create!(content: "Test step")

    get user_board_card_step_path(card.board.url_user, card.board, card, step), as: :json

    assert_response :success
    assert_equal step.id, @response.parsed_body["id"]
    assert_equal "Test step", @response.parsed_body["content"]
  end

  test "update as JSON" do
    card = cards(:logo)
    step = card.steps.create!(content: "Original")

    put user_board_card_step_path(card.board.url_user, card.board, card, step), params: { step: { content: "Updated" } }, as: :json

    assert_response :success
    assert_equal "Updated", step.reload.content
    assert_equal "Updated", @response.parsed_body["content"]
  end

  test "destroy as JSON" do
    card = cards(:logo)
    step = card.steps.create!(content: "To delete")

    delete user_board_card_step_path(card.board.url_user, card.board, card, step), as: :json

    assert_response :no_content
    assert_not Step.exists?(step.id)
  end
end
