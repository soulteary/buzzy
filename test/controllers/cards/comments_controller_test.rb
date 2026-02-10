require "test_helper"

class Cards::CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    assert_difference -> { cards(:logo).comments.count }, +1 do
      post user_board_card_comments_path(boards(:writebook).url_user, boards(:writebook), cards(:logo)), params: { comment: { body: "Agreed." } }, as: :turbo_stream
    end

    assert_response :success
  end

  test "create on draft card is forbidden" do
    draft_card = boards(:writebook).cards.create!(status: :drafted, creator: users(:kevin))

    assert_no_difference -> { draft_card.comments.count } do
      post user_board_card_comments_path(draft_card.board.url_user, draft_card.board, draft_card), params: { comment: { body: "This should be forbidden" } }, as: :json
    end

    assert_response :forbidden
  end

  test "mentioned user can create comment on hidden board card" do
    logout_and_sign_in_as :david
    board = boards(:private)
    card = cards(:secret_card)
    assert_not board.accessible_to?(users(:david)), "david should not have board access"

    assert_difference -> { card.comments.count }, +1 do
      post user_board_card_comments_path(board.url_user, board, card), params: { comment: { body: "Reply from mentioned user." } }, as: :turbo_stream
    end
    assert_response :success
  end

  test "update" do
    put user_board_card_comment_path(boards(:writebook).url_user, boards(:writebook), cards(:logo), comments(:logo_agreement_kevin)), params: { comment: { body: "I've changed my mind" } }, as: :turbo_stream

    assert_response :success
    assert_action_text "I've changed my mind", comments(:logo_agreement_kevin).reload.body
  end

  test "update another user's comment" do
    assert_no_changes -> { comments(:logo_agreement_jz).reload.body.to_s } do
      put user_board_card_comment_path(boards(:writebook).url_user, boards(:writebook), cards(:logo), comments(:logo_agreement_jz)), params: { comment: { body: "I've changed my mind" } }, as: :turbo_stream
    end

    assert_response :forbidden
  end

  test "index as JSON" do
    card = cards(:logo)

    get user_board_card_comments_path(card.board.url_user, card.board, card), as: :json

    assert_response :success
    assert_equal card.comments.count, @response.parsed_body.count
  end

  test "create as JSON" do
    card = cards(:logo)

    assert_difference -> { card.comments.count }, +1 do
      post user_board_card_comments_path(card.board.url_user, card.board, card), params: { comment: { body: "New comment" } }, as: :json
    end

    assert_response :created
    assert_equal user_board_card_comment_path(card.board.url_user, card.board, card, Comment.last, format: :json), @response.headers["Location"]
  end

  test "create as JSON with custom created_at" do
    card = cards(:logo)
    custom_time = Time.utc(2024, 1, 15, 10, 30, 0)

    assert_difference -> { card.comments.count }, +1 do
      post user_board_card_comments_path(card.board.url_user, card.board, card), params: { comment: { body: "Backdated comment", created_at: custom_time } }, as: :json
    end

    assert_response :created
    assert_equal custom_time, Comment.last.created_at
  end

  test "show as JSON" do
    comment = comments(:logo_agreement_kevin)

    get user_board_card_comment_path(comment.card.board.url_user, comment.card.board, comment.card, comment), as: :json

    assert_response :success
    assert_equal comment.id, @response.parsed_body["id"]
    assert_equal comment.card.id, @response.parsed_body.dig("card", "id")
    assert_equal user_board_card_url(comment.card.board.url_user, comment.card.board, comment.card), @response.parsed_body.dig("card", "url")
    assert_equal user_board_card_comment_reactions_url(comment.card.board.url_user, comment.card.board, comment.card, comment), @response.parsed_body["reactions_url"]
    assert_equal user_board_card_comment_url(comment.card.board.url_user, comment.card.board, comment.card, comment), @response.parsed_body["url"]
  end

  test "update as JSON" do
    comment = comments(:logo_agreement_kevin)

    put user_board_card_comment_path(boards(:writebook).url_user, boards(:writebook), cards(:logo), comment), params: { comment: { body: "Updated comment" } }, as: :json

    assert_response :success
    assert_equal "Updated comment", comment.reload.body.to_plain_text
  end

  test "destroy as JSON" do
    comment = comments(:logo_agreement_kevin)

    delete user_board_card_comment_path(boards(:writebook).url_user, boards(:writebook), cards(:logo), comment), as: :json

    assert_response :no_content
    assert_not Comment.exists?(comment.id)
  end
end
