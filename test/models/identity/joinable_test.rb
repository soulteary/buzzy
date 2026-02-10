require "test_helper"

class Identity::JoinableTest < ActiveSupport::TestCase
  test "join creates a new user when account has no real user" do
    identity = identities(:david)
    account = accounts(:acme) # acme has no users in fixtures

    assert_difference -> { User.count }, 1 do
      result = identity.join(account, name: "David")
      assert result, "join should return true when creating the first user"
    end

    user = identity.users.find_by!(account: account)
    assert_equal "David", user.name
  end

  test "join returns false when account already has a real user" do
    identity = identities(:mike)
    account = accounts("37s")

    assert account.users.where.not(role: :system).exists?, "37s should already have real users"

    assert_no_difference -> { User.count } do
      result = identity.join(account, name: "Mike")
      assert_not result, "join should return false when account already has a user"
    end
  end

  test "join returns false if user already exists" do
    identity = identities(:david)
    account = accounts("37s")

    assert identity.users.exists?(account: account), "David should already be a member of 37s"

    assert_no_difference -> { User.count } do
      result = identity.join(account)
      assert_not result, "join should return false when user already exists"
    end
  end
end
