require "test_helper"

class Card::AssignableTest < ActiveSupport::TestCase
  test "assigning a user makes them watch the card" do
    assert_not cards(:layout).assigned_to?(users(:kevin))
    cards(:layout).unwatch_by users(:kevin)

    with_current_user(:jz) do
      cards(:layout).toggle_assignment(users(:kevin))
    end

    assert cards(:layout).assigned_to?(users(:kevin))
    assert cards(:layout).watched_by?(users(:kevin))
  end

  test "toggle_assignment does not add assignee when at limit" do
    card = cards(:logo)
    board = card.board
    account = card.account

    card.assignments.delete_all

    Assignment::LIMIT.times do |i|
      identity = Identity.create!(email_address: "toggle_test_#{i}@example.com")
      user = account.users.create!(identity: identity, name: "Toggle Test User #{i}", role: :member)
      user.accesses.find_or_create_by!(board: board)
      card.assignments.create!(assignee: user, assigner: users(:david))
    end

    identity = Identity.create!(email_address: "toggle_over@example.com")
    extra_user = account.users.create!(identity: identity, name: "Toggle Over User", role: :member)
    extra_user.accesses.find_or_create_by!(board: board)

    with_current_user(:david) do
      assert_no_difference "card.assignments.count" do
        card.toggle_assignment(extra_user)
      end
    end

    assert_not card.reload.assigned_to?(extra_user)
  end

  test "assigning cross-account user does not grant board access, only card access" do
    card = cards(:logo)
    assignee = users(:mike)

    assert_not card.board.accessible_to?(assignee)

    with_current_user(:kevin) do
      card.toggle_assignment(assignee)
    end

    assert card.reload.assigned_to?(assignee)
    assert_not card.board.accessible_to?(assignee), "Assignee should not gain full board access"
    assert card.accessible_to?(assignee), "Assignee should still be able to access the assigned card"
    assert_not card.board.accesses.exists?(user_id: assignee.id)
  end
end
