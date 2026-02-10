# frozen_string_literal: true

require "test_helper"

class CardPolicyTest < ActiveSupport::TestCase
  test "editable? returns false when card is blank" do
    user = users(:david)
    assert_equal false, CardPolicy.editable?(user, nil, board_accessed_via_mention: false)
  end

  test "editable? returns false when user is blank" do
    card = cards(:logo)
    assert_equal false, CardPolicy.editable?(nil, card, board_accessed_via_mention: false)
  end

  test "editable? returns false when board_accessed_via_mention is true" do
    user = users(:david)
    card = cards(:logo)
    assert_equal false, CardPolicy.editable?(user, card, board_accessed_via_mention: true)
  end

  test "editable? returns true when user same account and not mention access" do
    user = users(:david)
    card = cards(:logo)
    assert_equal user.account_id, card.account_id, "fixtures should share account"
    assert_equal true, CardPolicy.editable?(user, card, board_accessed_via_mention: false)
  end

  test "editable? returns true for super admin without current user" do
    card = cards(:secret_card)
    assert_equal true, CardPolicy.editable?(nil, card, board_accessed_via_mention: true, super_admin: true)
  end

  test "from_other_account? returns false when user and card same account" do
    user = users(:david)
    card = cards(:logo)
    assert_equal false, CardPolicy.from_other_account?(user, card)
  end

  test "from_other_account? returns false for super admin" do
    user = users(:mike)
    card = cards(:logo)
    assert_equal true, user.account_id != card.account_id, "fixtures should be cross-account"
    assert_equal false, CardPolicy.from_other_account?(user, card, super_admin: true)
  end

  test "assignees_read_only? returns true when user is blank" do
    card = cards(:logo)
    assert_equal true, CardPolicy.assignees_read_only?(
      nil, card,
      board_accessed_via_mention: false,
      from_other_account: false,
      viewing_other_user_as_limited_viewer: false
    )
  end

  test "assignees_read_only? returns true when board_accessed_via_mention" do
    user = users(:david)
    card = cards(:logo)
    assert_equal true, CardPolicy.assignees_read_only?(
      user, card,
      board_accessed_via_mention: true,
      from_other_account: false,
      viewing_other_user_as_limited_viewer: false
    )
  end

  test "deletable? returns false when board_accessed_via_mention" do
    user = users(:jason)
    card = cards(:logo)
    assert_equal false, CardPolicy.deletable?(user, card, board_accessed_via_mention: true)
  end

  test "deletable? returns true for super admin without current user" do
    card = cards(:secret_card)
    assert_equal true, CardPolicy.deletable?(nil, card, board_accessed_via_mention: true, super_admin: true)
  end

  test "assignees_read_only? returns false for super admin" do
    card = cards(:logo)
    assert_equal false, CardPolicy.assignees_read_only?(
      nil, card,
      board_accessed_via_mention: true,
      from_other_account: true,
      viewing_other_user_as_limited_viewer: true,
      super_admin: true
    )
  end
end
