# frozen_string_literal: true

require "test_helper"

class OperationLogTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:'37s')
    @board = boards(:writebook)
    @user = users(:david)
  end

  test "log! creates record with required attributes" do
    assert_difference "OperationLog.count", 1 do
      OperationLog.log!(
        action: :create,
        account: @account,
        board: @board,
        user: @user,
        subject: cards(:logo),
        changes: { "title" => [ nil, "Logo" ] }
      )
    end

    log = OperationLog.last
    assert_equal "create", log.action
    assert_equal @account.id, log.account_id
    assert_equal @board.id, log.board_id
    assert_equal @user.id, log.user_id
    assert_equal "Card", log.subject_type
    assert_equal cards(:logo).id, log.subject_id
    assert_equal({ "title" => [ nil, "Logo" ] }, log.changes)
  end

  test "log! allows optional board and user" do
    OperationLog.log!(action: "destroy", account: @account, user: nil, board: nil)
    log = OperationLog.last
    assert_nil log.board_id
    assert_nil log.user_id
    assert_equal "destroy", log.action
  end

  test "validates action inclusion" do
    log = OperationLog.new(account: @account, action: "invalid")
    assert_not log.valid?
    assert_includes log.errors[:action], "is not included in the list"
  end

  test "validates account presence" do
    log = OperationLog.new(action: "create")
    assert_not log.valid?
    assert_includes log.errors[:account_id], "can't be blank"
  end

  test "chronological scope orders by created_at desc" do
    rel = OperationLog.for_account(@account.id).chronological
    assert_match(/order.*created_at.*desc/i, rel.to_sql)
  end

  test "creating a card creates an operation log when Current is set" do
    Current.session = sessions(:david)
    user = users(:david)
    board = boards(:writebook)

    assert_difference "OperationLog.count", 1 do
      Card.create!(title: "OpLog Test", board: board, creator: user)
    end

    log = OperationLog.last
    assert_equal "create", log.action
    assert_equal "Card", log.subject_type
    assert_equal @account.id, log.account_id
    assert_equal board.id, log.board_id
    assert_equal user.id, log.user_id
  end

  test "destroying a card creates an operation log when Current is set" do
    Current.session = sessions(:david)
    user = users(:david)
    board = boards(:writebook)
    card = Card.create!(title: "To destroy", board: board, creator: user)
    card_id = card.id
    count_before = OperationLog.count

    card.destroy!

    assert_equal count_before + 2, OperationLog.count, "create + destroy logs"
    log = OperationLog.where(subject_type: "Card", subject_id: card_id, action: "destroy").last
    assert log, "expected one destroy log for the card"
    assert_equal @account.id, log.account_id
    assert log.changes.present?
  end
end
