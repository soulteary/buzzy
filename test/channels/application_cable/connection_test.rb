require "test_helper"

module ApplicationCable
  class ConnectionTest < ActionCable::Connection::TestCase
    setup do
      # Use non-37s account to assess that Current.account is set correctly
      @account = accounts(:initech)
      @session = sessions(:mike)
    end

    test "connects with valid session and account info" do
      cookies.signed[:session_token] = @session.signed_id

      connect "/cable", env: { "buzzy.account_id" => @account.id }

      assert_equal users(:mike), connection.current_user
      assert_equal @account, Current.account
    end

    test "rejects with invalid session token" do
      cookies.signed[:session_token] = "invalid-session-id"

      assert_reject_connection do
        connect "/cable", env: { "buzzy.account_id" => @account.id }
      end
    end

    test "rejects when account does not exist" do
      cookies.signed[:session_token] = @session.signed_id

      assert_reject_connection do
        connect "/cable", env: { "buzzy.account_id" => "0" * 25 }
      end
    end
  end
end
