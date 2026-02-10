require "test_helper"

class Identity::TransferableTest < ActiveSupport::TestCase
  test "transfer_id returns hyphenated UUID string" do
    identity = identities(:david)
    transfer_id = identity.transfer_id

    assert_kind_of String, transfer_id
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i, transfer_id)
  end

  test "find_by_transfer_id" do
    identity = identities(:kevin)
    transfer_id = identity.transfer_id

    found = Identity.find_by_transfer_id(transfer_id)
    assert_equal identity, found

    found = Identity.find_by_transfer_id("invalid_id")
    assert_nil found

    expired_id = identity.signed_id(purpose: :transfer, expires_in: -1.second)
    found = Identity.find_by_transfer_id(expired_id)
    assert_nil found
  end

  test "transfer_id and find_by_transfer_id are disabled when Buzzy.session_transfer_enabled? is false" do
    identity = identities(:kevin)
    Buzzy.instance_variable_set(:@session_transfer_enabled, false)

    assert_nil identity.transfer_id
    assert_nil Identity.find_by_transfer_id(identity.transfer_id || "any-id")
  ensure
    Buzzy.remove_instance_variable(:@session_transfer_enabled) if Buzzy.instance_variable_defined?(:@session_transfer_enabled)
  end
end
