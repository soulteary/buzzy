require "test_helper"

class Cards::Comments::ReactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :david
    @comment = comments(:logo_agreement_jz)
    @card = @comment.card
  end

  test "index" do
    get user_board_card_comment_reactions_path(@card.board.url_user, @card.board, @card, @comment)
    assert_response :success
  end

  test "create" do
    assert_difference -> { @comment.reactions.count }, 1 do
      post user_board_card_comment_reactions_path(@comment.card.board.url_user, @comment.card.board, @comment.card, @comment, format: :turbo_stream), params: { reaction: { content: "Great work!" } }
      assert_turbo_stream action: :replace, target: dom_id(@comment, :reacting)
    end
  end

  test "mentioned user can create reaction on hidden board card comment" do
    logout_and_sign_in_as :david
    board = boards(:private)
    card = cards(:secret_card)
    assert_not board.accessible_to?(users(:david)), "david should not have board access"
    comment = card.comments.create!(body: "Comment for reaction by mentioned user.", creator: users(:kevin))

    assert_difference -> { comment.reactions.count }, 1 do
      post user_board_card_comment_reactions_path(board.url_user, board, card, comment, format: :turbo_stream), params: { reaction: { content: "👍" } }
      assert_turbo_stream action: :replace, target: dom_id(comment, :reacting)
    end
    assert_response :success
  end

  test "new works when script_name account has no current user but identity user can access board" do
    logout_and_sign_in_as :david
    board = boards(:private)
    Access.find_or_create_by!(board: board, user: users(:david), account: board.account)
    card = board.cards.create!(title: "Board access fallback card", creator: users(:kevin), status: :published, account: board.account)
    comment = card.comments.create!(body: "Comment for board fallback reaction.", creator: users(:kevin))

    original_script_name = integration_session.default_url_options[:script_name]
    integration_session.default_url_options[:script_name] = accounts(:initech).to_param
    get new_user_board_card_comment_reaction_path(board.url_user, board, card, comment)
    assert_response :success
  ensure
    integration_session.default_url_options[:script_name] = original_script_name
  end

  test "create notifies comment creator when commenter is not card creator" do
    assert_not_equal @card.creator, @comment.creator

    assert_difference -> { @comment.creator.notifications.where(source_type: "Reaction").count }, 1 do
      perform_enqueued_jobs only: NotifyRecipientsJob do
        post user_board_card_comment_reactions_path(@comment.card.board.url_user, @comment.card.board, @comment.card, @comment, format: :turbo_stream), params: { reaction: { content: "👍" } }
      end
    end

    notification = @comment.creator.notifications.where(source_type: "Reaction").last
    assert_equal users(:david), notification.creator
    assert_equal @comment, notification.source.reactable
  end

  test "create notifies comment creator identities across accounts when commenter is not card creator" do
    assert_not_equal @card.creator, @comment.creator
    other_account_user = User.create!(
      name: "JZ Other Account",
      role: :member,
      identity: @comment.creator.identity,
      account: accounts(:initech),
      verified_at: Time.current
    )

    assert_difference -> { @comment.creator.notifications.where(source_type: "Reaction").count }, 1 do
      assert_difference -> { other_account_user.notifications.where(source_type: "Reaction").count }, 1 do
        perform_enqueued_jobs only: NotifyRecipientsJob do
          post user_board_card_comment_reactions_path(@comment.card.board.url_user, @comment.card.board, @comment.card, @comment, format: :turbo_stream), params: { reaction: { content: "🔥" } }
        end
      end
    end

    notification = other_account_user.notifications.where(source_type: "Reaction").last
    assert_equal users(:david), notification.creator
    assert_equal @comment, notification.source.reactable
  end

  test "destroy" do
    reaction = reactions(:david)
    assert_difference -> { @comment.reactions.count }, -1 do
      delete user_board_card_comment_reaction_path(@comment.card.board.url_user, @comment.card.board, @comment.card, @comment, reaction, format: :turbo_stream)
      assert_turbo_stream action: :remove, target: dom_id(reaction)
    end
  end

  test "non-owner cannot destroy reaction" do
    reaction = reactions(:kevin)

    assert_no_difference -> { @comment.reactions.count } do
      delete user_board_card_comment_reaction_path(@comment.card.board.url_user, @comment.card.board, @comment.card, @comment, reaction, format: :turbo_stream)
      assert_response :forbidden
    end
  end

  test "index as JSON" do
    get user_board_card_comment_reactions_path(@card.board.url_user, @card.board, @card, @comment), as: :json

    assert_response :success
    assert_equal @comment.reactions.count, @response.parsed_body.count
  end

  test "create as JSON" do
    assert_difference -> { @comment.reactions.count }, 1 do
      post user_board_card_comment_reactions_path(@card.board.url_user, @card.board, @card, @comment), params: { reaction: { content: "👍" } }, as: :json
    end

    assert_response :created
  end

  test "destroy as JSON" do
    reaction = reactions(:david)

    assert_difference -> { @comment.reactions.count }, -1 do
      delete user_board_card_comment_reaction_path(@card.board.url_user, @card.board, @card, @comment, reaction), as: :json
    end

    assert_response :no_content
  end
end
