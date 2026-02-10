require "test_helper"

class Cards::ReactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
    @card = cards(:logo)
  end

  test "index" do
    get user_board_card_reactions_path(@card.board.url_user, @card.board, @card)
    assert_response :success
  end

  test "new" do
    get new_user_board_card_reaction_path(@card.board.url_user, @card.board, @card)
    assert_response :success
  end

  test "create" do
    assert_difference -> { @card.reactions.count }, 1 do
      post user_board_card_reactions_path(@card.board.url_user, @card.board, @card, format: :turbo_stream), params: { reaction: { content: "Great work!" } }
      assert_turbo_stream action: :replace, target: dom_id(@card, :reacting)
    end
  end

  test "mentioned user can create reaction on hidden board card" do
    logout_and_sign_in_as :david
    board = boards(:private)
    card = cards(:secret_card)
    assert_not board.accessible_to?(users(:david)), "david should not have board access"

    assert_difference -> { card.reactions.count }, 1 do
      post user_board_card_reactions_path(board.url_user, board, card, format: :turbo_stream), params: { reaction: { content: "🔥" } }
      assert_turbo_stream action: :replace, target: dom_id(card, :reacting)
    end
    assert_response :success
  end

  test "destroy" do
    reaction = reactions(:logo_card_david)
    assert_difference -> { @card.reactions.count }, -1 do
      delete user_board_card_reaction_path(@card.board.url_user, @card.board, @card, reaction, format: :turbo_stream)
      assert_turbo_stream action: :remove, target: dom_id(reaction)
    end
  end

  test "non-owner cannot destroy reaction" do
    reaction = reactions(:logo_card_kevin)

    assert_no_difference -> { @card.reactions.count } do
      delete user_board_card_reaction_path(@card.board.url_user, @card.board, @card, reaction, format: :turbo_stream)
      assert_response :forbidden
    end
  end

  test "index as JSON" do
    get user_board_card_reactions_path(@card.board.url_user, @card.board, @card), as: :json

    assert_response :success
    assert_equal @card.reactions.count, @response.parsed_body.count
  end

  test "create as JSON" do
    assert_difference -> { @card.reactions.count }, 1 do
      post user_board_card_reactions_path(@card.board.url_user, @card.board, @card), params: { reaction: { content: "👍" } }, as: :json
    end

    assert_response :created
  end

  test "destroy as JSON" do
    reaction = reactions(:logo_card_david)

    assert_difference -> { @card.reactions.count }, -1 do
      delete user_board_card_reaction_path(@card.board.url_user, @card.board, @card, reaction), as: :json
    end

    assert_response :no_content
  end
end
