require "test_helper"

class JoinCodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts("37s")
    @join_code = account_join_codes(:"37s")
  end

  test "new" do
    get join_path(code: @join_code.code, script_name: @account.slug)

    assert_response :success
    assert_in_body "37signals"
  end

  test "new with an invalid code" do
    get join_path(code: "INVALID-CODE", script_name: @account.slug)

    assert_response :not_found
  end

  test "new with an inactive code" do
    @join_code.update!(usage_count: @join_code.usage_limit)

    get join_path(code: @join_code.code, script_name: @account.slug)

    assert_response :gone
    assert_in_body "That code is all used up"
  end

  test "create" do
    assert_difference -> { Identity.count }, 1 do
      assert_difference -> { User.count }, 1 do
        post join_path(code: @join_code.code, script_name: @account.slug), params: { email_address: "new_user@example.com" }
      end
    end

    assert_redirected_to session_magic_link_url(script_name: nil)
    assert_equal new_users_join_url(script_name: @account.slug), session[:return_to_after_authenticating]
  end

  test "create for existing identity" do
    identity = identities(:jz)
    sign_in_as :jz

    assert identity.users.exists?(account: @account), "JZ should be a member of 37s for this test"
    assert identity.users.find_by!(account: @account).setup?, "JZ's user should be setup for this test"

    assert_no_difference -> { Identity.count } do
      assert_no_difference -> { User.count } do
        post join_path(code: @join_code.code, script_name: @account.slug), params: { email_address: identity.email_address }
      end
    end

    assert_redirected_to landing_url(script_name: @account.slug)
  end

  test "create for signed-in identity without a user in the account redirects to user setup" do
    identity = identities(:mike)
    sign_in_as :mike

    assert_not identity.users.exists?(account: @account), "Mike should not be a member of 37s for this test"

    assert_no_difference -> { Identity.count } do
      assert_difference -> { User.count }, 1 do
        post join_path(code: @join_code.code, script_name: @account.slug), params: { email_address: identity.email_address }
      end
    end

    assert_redirected_to new_users_join_url(script_name: @account.slug)
  end
end
