require "test_helper"

class User::AccessorTest < ActiveSupport::TestCase
  test "new users get added to all_access boards on creation" do
    user = User.create!(account: accounts("37s"), name: "Jorge")

    assert_includes user.boards, boards(:writebook)
    assert_equal user.account.boards.all_access.count, user.boards.count
  end

  test "system user does not get added to boards on creation" do
    system_user = User.create!(account: accounts("37s"), role: "system", name: "Test System User")
    assert_empty system_user.boards
  end

  test "cards_visible_in_board_for_limited_view returns only mention and assignment cards in board" do
    board = boards(:private)
    card = cards(:secret_card)
    david = users(:david)
    kevin = users(:kevin)
    # Ensure david is mentioned on secret_card (fixture may already have this)
    unless david.mentions.where(source: card).exists?
      Mention.create!(account: board.account, source: card, mentioner: kevin, mentionee: david)
    end
    assert_not board.accessible_to?(david), "david should not have board access"
    assert david.cards_accessible_via_mention(board.account).exists?(id: card.id), "david is mentioned on card"

    limited = david.cards_visible_in_board_for_limited_view(board)
    assert_includes limited, card
    assert_equal 1, limited.count
    assert_equal [ card.id ], limited.pluck(:id).sort
    # Cards on this board that david is not mentioned on must not appear
    assert_equal 0, limited.where.not(id: card.id).count
  end

  test "creating a new card draft sets current timestamps" do
    user = users(:david)
    board = boards(:writebook)

    freeze_time do
      card = user.draft_new_card_in(board)

      assert card.persisted?
      assert card.drafted?
      assert_equal user, card.creator
      assert_equal board, card.board
      assert_equal Time.current, card.created_at
      assert_equal Time.current, card.updated_at
      assert_equal Time.current, card.last_active_at
    end
  end

  test "reusing an existing card draft refreshes timestamps" do
    existing_draft = cards(:unfinished_thoughts)
    user = existing_draft.creator
    board = existing_draft.board

    freeze_time do
      card = user.draft_new_card_in(board)

      assert_equal existing_draft, card
      assert_equal Time.current, card.created_at
      assert_equal Time.current, card.updated_at
      assert_equal Time.current, card.last_active_at
    end
  end
end
