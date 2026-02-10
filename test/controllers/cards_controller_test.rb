require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get cards_path
    assert_response :success
  end

  test "filtered index" do
    get cards_path(filters(:jz_assignments).as_params.merge(term: "haggis"))
    assert_response :success
  end

  test "single-user account keeps assignee filter fields in form" do
    account = accounts("37s")
    current_user = users(:kevin)
    account.users.where.not(id: current_user.id).update_all(active: false)

    get cards_path(assignee_ids: [ current_user.to_param ], indexed_by: "all", sorted_by: "newest")
    assert_response :success
    assert_includes response.body, %(name="assignee_ids[]")
    assert_includes response.body, %(value="#{current_user.id}")
  end

  test "keeps creator filter fields in form" do
    current_user = users(:kevin)

    get cards_path(creator_ids: [ current_user.to_param ], indexed_by: "all", sorted_by: "latest")
    assert_response :success
    assert_includes response.body, %(name="creator_ids[]")
    assert_includes response.body, %(value="#{current_user.id}")
  end

  test "create a new draft" do
    board = boards(:writebook)
    assert_difference -> { Card.count }, 1 do
      post user_board_cards_path(board.url_user, board)
    end

    card = Card.last
    assert_redirected_to user_board_card_draft_path(card.board.url_user, card.board, card)

    assert card.drafted?
  end

  test "create resumes existing draft if it exists" do
    board = boards(:writebook)
    draft = board.cards.create!(creator: users(:kevin), status: :drafted)

    assert_no_difference -> { Card.count } do
      post user_board_cards_path(board.url_user, board)
      assert_redirected_to user_board_card_draft_path(draft.board.url_user, draft.board, draft)
    end
  end

  test "show redirects to draft when card is drafted" do
    card = boards(:writebook).cards.create!(creator: users(:kevin), status: :drafted)

    get user_board_card_path(card.board.url_user, card.board, card)
    assert_redirected_to user_board_card_draft_path(card.board.url_user, card.board, card)
  end

  test "show" do
    board = boards(:writebook)
    card = cards(:logo)
    get user_board_card_path(board.url_user, board, card)
    assert_response :success
  end

  test "edit" do
    board = boards(:writebook)
    card = cards(:logo)
    get edit_user_board_card_path(board.url_user, board, card)
    assert_response :success
  end

  test "edit card with invalid attachments in description" do
    card = cards(:logo)
    card.update! description: <<~HTML
      <action-text-attachment sgid="gid://buzzy/Card/nonexistent" content-type="application/octet-stream"></action-text-attachment>
    HTML

    get edit_user_board_card_path(card.board.url_user, card.board, card)
    assert_response :success
  end

  test "update" do
    board = boards(:writebook)
    card = cards(:logo)
    patch user_board_card_path(board.url_user, board, card), as: :turbo_stream, params: {
      card: {
        title: "Logo needs to change",
        image: fixture_file_upload("moon.jpg", "image/jpeg"),
        description: "Something more in-depth" } }
    assert_response :success

    card = cards(:logo).reload
    assert_equal "Logo needs to change", card.title
    assert_equal "moon.jpg", card.image.filename.to_s
    assert_equal "Something more in-depth", card.description.to_plain_text.strip
  end

  test "update draft card does not render reactions" do
    draft = boards(:writebook).cards.create!(creator: users(:kevin), status: :drafted)

    patch user_board_card_path(draft.board.url_user, draft.board, draft), as: :turbo_stream, params: {
      card: { image: fixture_file_upload("moon.jpg", "image/jpeg") }
    }
    assert_response :success

    assert_no_match "reactions", response.body, "Draft card should not show reactions/boost button"
  end

  test "users can only see cards in boards they have access to" do
    board = boards(:writebook)
    card = cards(:logo)
    get user_board_card_path(board.url_user, board, card)
    assert_response :success

    board.update! all_access: false
    board.accesses.revoke_from users(:kevin)

    get user_board_card_path(board.url_user, board, card)
    assert_response :not_found
  end

  test "mentioned user can show card on hidden board via notification link" do
    logout_and_sign_in_as :david
    board = boards(:private)
    card = cards(:secret_card)
    assert_not board.accessible_to?(users(:david)), "david should not have board access"

    get user_board_card_path(board.url_user, board, card)
    assert_response :success
  end

  test "mentioned user can show hidden-board card with foreign script_name account" do
    logout_and_sign_in_as :david
    board = boards(:private)
    card = cards(:secret_card)
    assert_not board.accessible_to?(users(:david)), "david should not have board access"

    original_script_name = integration_session.default_url_options[:script_name]
    integration_session.default_url_options[:script_name] = accounts(:initech).to_param
    get user_board_card_path(board.url_user, board, card)
    assert_response :success
  ensure
    integration_session.default_url_options[:script_name] = original_script_name
  end

  test "mentioned user cannot edit or update or destroy card on hidden board" do
    logout_and_sign_in_as :david
    board = boards(:private)
    card = cards(:secret_card)

    get edit_user_board_card_path(board.url_user, board, card)
    assert_response :forbidden

    patch user_board_card_path(board.url_user, board, card), as: :turbo_stream, params: { card: { title: "Hacked" } }
    assert_response :forbidden

    assert_no_difference -> { Card.count } do
      delete user_board_card_path(board.url_user, board, card)
    end
    assert_response :forbidden
  end

  test "mentioned user cannot access other cards on same hidden board" do
    board = boards(:private)
    card = cards(:secret_card)
    other_card = board.cards.create!(creator: users(:kevin), title: "Other", status: :published, account: board.account, column: board.columns.first!)
    assert_not board.accessible_to?(users(:david)), "david should not have board access"
    assert users(:david).cards_accessible_via_mention(board.account).exists?(id: card.id), "david is mentioned on secret_card"
    assert_not users(:david).cards_accessible_via_mention(board.account).exists?(id: other_card.id), "david is not mentioned on other_card"

    logout_and_sign_in_as :david
    get user_board_card_path(board.url_user, board, other_card)
    assert_response :not_found
  end

  test "user mentioned only in comment can show that card on non-public board" do
    board = boards(:private)
    card = cards(:secret_card)
    assert_not board.accessible_to?(users(:jz)), "jz should not have board access"

    comment = card.comments.create!(creator: users(:kevin), body: "FYI @jz")
    Mention.create!(account: board.account, source: comment, mentioner: users(:kevin), mentionee: users(:jz))

    logout_and_sign_in_as :jz
    get user_board_card_path(board.url_user, board, card)
    assert_response :success
  end

  test "user mentioned in comment can show card with foreign script_name account" do
    board = boards(:private)
    card = cards(:secret_card)
    assert_not board.accessible_to?(users(:jz)), "jz should not have board access"

    comment = card.comments.create!(creator: users(:kevin), body: "FYI @jz")
    Mention.create!(account: board.account, source: comment, mentioner: users(:kevin), mentionee: users(:jz))

    logout_and_sign_in_as :jz
    original_script_name = integration_session.default_url_options[:script_name]
    integration_session.default_url_options[:script_name] = accounts(:initech).to_param
    get user_board_card_path(board.url_user, board, card)
    assert_response :success
  ensure
    integration_session.default_url_options[:script_name] = original_script_name
  end

  test "cross-account viewer on public board can comment" do
    logout_and_sign_in_as :mike
    board = boards(:writebook)
    card = cards(:logo)
    assert board.all_access?, "writebook is public"

    assert_difference -> { card.comments.count }, 1 do
      post user_board_card_comments_path(board.url_user, board, card), params: { comment: { body: "Cross-account comment." } }, as: :turbo_stream
    end
    assert_response :success
  end

  test "cross-account viewer on public board does not see assign button" do
    logout_and_sign_in_as :mike
    board = boards(:writebook)
    card = cards(:logo)

    get user_board_card_path(board.url_user, board, card)
    assert_response :success
    assert_no_match "icon--person-add", response.body
  end

  test "cross-account viewer can open public card even with foreign user id in path" do
    logout_and_sign_in_as :mike
    board = boards(:writebook)
    card = cards(:logo)
    foreign_user = users(:mike)

    get user_board_card_path(foreign_user, board, card)
    assert_response :success
  end

  test "admins can see delete button on any card" do
    board = boards(:writebook)
    card = cards(:logo)
    get user_board_card_path(board.url_user, board, card)
    assert_response :success

    assert_match "Delete this card", response.body
  end

  test "card creators can see delete button on their own cards" do
    board = boards(:writebook)
    card = cards(:logo)
    logout_and_sign_in_as :david

    get user_board_card_path(board.url_user, board, card)
    assert_response :success

    assert_match "Delete this card", response.body
  end

  test "non-admins cannot see delete button on cards they did not create" do
    board = boards(:writebook)
    card = cards(:logo)
    logout_and_sign_in_as :jz

    get user_board_card_path(board.url_user, board, card)
    assert_response :success

    assert_no_match "Delete this card", response.body
  end

  test "non-admins cannot delete cards they did not create" do
    board = boards(:writebook)
    card = cards(:logo)
    logout_and_sign_in_as :jz

    assert_no_difference -> { Card.count } do
      delete user_board_card_path(board.url_user, board, card)
    end

    assert_response :forbidden
  end

  test "card creators can delete their own cards" do
    board = boards(:writebook)
    card = cards(:logo)
    logout_and_sign_in_as :david

    assert_difference -> { Card.count }, -1 do
      delete user_board_card_path(board.url_user, board, card)
    end

    assert_redirected_to board
  end

  test "admins can delete any card" do
    board = boards(:writebook)
    card = cards(:logo)
    assert_difference -> { Card.count }, -1 do
      delete user_board_card_path(board.url_user, board, card)
    end

    assert_redirected_to board
  end

  test "super admin can update non-public card across account without account user" do
    logout_and_sign_in_as :mike
    board = boards(:private)
    card = cards(:secret_card)
    email = users(:mike).identity.email_address

    Buzzy.stub(:admin_emails, [ email ].to_set) do
      patch user_board_card_path(board.url_user, board, card), as: :turbo_stream, params: {
        card: { title: "Super admin edited title" }
      }
    end

    assert_response :success
    assert_equal "Super admin edited title", card.reload.title
  end

  test "super admin can open card edit across account without account user" do
    logout_and_sign_in_as :mike
    board = boards(:private)
    card = cards(:secret_card)
    email = users(:mike).identity.email_address

    Buzzy.stub(:admin_emails, [ email ].to_set) do
      get edit_user_board_card_path(board.url_user, board, card)
    end

    assert_response :success
  end

  test "show card with comment containing malformed remote image attachment" do
    card = cards(:logo)
    card.comments.create! \
      creator: users(:kevin),
      body: '<action-text-attachment url="image.png" content-type="image/*" presentation="gallery"></action-text-attachment>'

    get user_board_card_path(card.board.url_user, card.board, card)
    assert_response :success
  end

  test "show card falls back to gid for attachment when sgid is invalid" do
    card = cards(:logo)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("hello"),
      filename: "fallback.txt",
      content_type: "text/plain"
    )
    invalid_html = <<~HTML
      <action-text-attachment sgid="invalid-sgid" gid="#{blob.to_global_id}" content-type="text/plain"></action-text-attachment>
    HTML
    card.description.update_column(:body, invalid_html)

    get user_board_card_path(card.board.url_user, card.board, card)
    assert_response :success
    assert_match "fallback.txt", response.body
    assert_no_match "☒", response.body
  end

  test "show card renders remote video attachment from url node" do
    card = cards(:logo)
    card.description.update_column(
      :body,
      '<action-text-attachment url="/video/not-now.mp4" caption="移到暂不处理" content-type="video/mp4" filename="not-now.mp4" presentation="gallery"></action-text-attachment>'
    )

    get user_board_card_path(card.board.url_user, card.board, card)
    assert_response :success
    assert_match "/video/not-now.mp4", response.body
    assert_no_match "☒", response.body
  end

  test "update infers mention user from content image src when sgid is invalid" do
    board = boards(:writebook)
    card = cards(:logo)
    user = users(:kevin)
    mention_html = <<~HTML
      <action-text-attachment sgid="invalid-sgid" content="&quot;&lt;img src=&quot;/users/#{user.id}/avatar&quot;&gt;#{user.name}&quot;" content-type="application/vnd.actiontext.mention"></action-text-attachment>
    HTML

    patch user_board_card_path(board.url_user, board, card), as: :turbo_stream, params: {
      card: {
        description: mention_html
      }
    }

    assert_response :success
    html = card.reload.description.body.to_html
    assert_match user.to_global_id.to_s, html
    assert_no_match "Unknown user", html
  end

  test "show as JSON" do
    card = cards(:logo)
    card.steps.create!(content: "First step")
    card.steps.create!(content: "Second step", completed: true)

    get user_board_card_path(card.board.url_user, card.board, card), as: :json
    assert_response :success

    assert_equal card.title, @response.parsed_body["title"]
    assert_equal card.closed?, @response.parsed_body["closed"]
    assert_equal 2, @response.parsed_body["steps"].size
    assert_equal user_board_card_comments_url(card.board.url_user, card.board, card), @response.parsed_body["comments_url"]
    assert_equal user_board_card_reactions_url(card.board.url_user, card.board, card), @response.parsed_body["reactions_url"]
  end

  test "create as JSON" do
    board = boards(:writebook)
    assert_difference -> { Card.count }, +1 do
      post user_board_cards_path(board.url_user, board),
        params: { card: { title: "My new card", description: "Big if true" } },
        as: :json
      assert_response :created
    end

    card = Card.last
    assert_equal user_board_card_path(card.board.url_user, card.board, card, format: :json), @response.headers["Location"]

    assert_equal "My new card", card.title
    assert_equal "Big if true", card.description.to_plain_text
  end

  test "create as JSON with custom created_at" do
    board = boards(:writebook)
    custom_time = Time.utc(2024, 1, 15, 10, 30, 0)

    assert_difference -> { Card.count }, +1 do
      post user_board_cards_path(board.url_user, board),
        params: { card: { title: "Backdated card", created_at: custom_time } },
        as: :json
      assert_response :created
    end

    assert_equal custom_time, Card.last.created_at
  end

  test "create as JSON with custom last_active_at" do
    board = boards(:writebook)
    created_time = Time.utc(2024, 1, 15, 10, 30, 0)
    last_active_time = Time.utc(2024, 6, 1, 12, 0, 0)

    assert_difference -> { Card.count }, +1 do
      post user_board_cards_path(board.url_user, board),
        params: { card: { title: "Card with activity", created_at: created_time, last_active_at: last_active_time } },
        as: :json
      assert_response :created
    end

    card = Card.last
    assert_equal created_time, card.created_at
    assert_equal last_active_time, card.last_active_at
  end

  test "create as JSON defaults last_active_at to created_at when not provided" do
    board = boards(:writebook)
    created_time = Time.utc(2024, 1, 15, 10, 30, 0)

    assert_difference -> { Card.count }, +1 do
      post user_board_cards_path(board.url_user, board),
        params: { card: { title: "Backdated card without last_active_at", created_at: created_time } },
        as: :json
      assert_response :created
    end

    card = Card.last
    assert_equal created_time, card.created_at
    assert_equal created_time, card.last_active_at
  end

  test "update as JSON with custom last_active_at" do
    card = cards(:logo)
    custom_time = Time.utc(2024, 3, 15, 14, 0, 0)

    put user_board_card_path(card.board.url_user, card.board, card, format: :json), params: { card: { last_active_at: custom_time } }

    assert_response :success
    assert_equal custom_time, card.reload.last_active_at
  end

  test "update as JSON can restore last_active_at after comments overwrite it" do
    board = boards(:writebook)
    created_time = Time.utc(2024, 1, 15, 10, 30, 0)
    last_active_time = Time.utc(2024, 6, 1, 12, 0, 0)

    # Create a card with custom timestamps (simulating import)
    post user_board_cards_path(board.url_user, board),
      params: { card: { title: "Imported card", created_at: created_time, last_active_at: last_active_time } },
      as: :json
    assert_response :created

    card = Card.last

    # Adding a comment overwrites last_active_at (this is expected)
    card.comments.create!(creator: users(:kevin), body: "Imported comment")
    assert_not_equal last_active_time, card.reload.last_active_at

    # After import, restore the correct last_active_at
    put user_board_card_path(card.board.url_user, card.board, card, format: :json), params: { card: { last_active_at: last_active_time } }
    assert_response :success

    assert_equal last_active_time, card.reload.last_active_at
  end

  test "update as JSON" do
    card = cards(:logo)

    put user_board_card_path(card.board.url_user, card.board, card, format: :json), params: { card: { title: "Update test" } }
    assert_response :success

    assert_equal "Update test", card.reload.title
  end

  test "delete as JSON" do
    card = cards(:logo)

    delete user_board_card_path(card.board.url_user, card.board, card, format: :json)
    assert_response :no_content

    assert_not Card.exists?(card.id)
  end
end
