require "test_helper"
require "rack/mock"

class AccountSlugExtractorTest < ActiveSupport::TestCase
  test "moves account UUID prefix from PATH_INFO to SCRIPT_NAME" do
    account = accounts(:initech)
    slug = AccountSlug.encode(account)

    captured = call_with_env "/#{slug}/boards"

    assert_equal "/#{slug}", captured.fetch(:script_name)
    assert_equal "/boards", captured.fetch(:path_info)
    assert_equal account.id, captured.fetch(:account_id)
    assert_equal account, captured.fetch(:current_account)
  end

  test "treats a bare account UUID prefix as the root path" do
    account = accounts(:initech)
    slug = AccountSlug.encode(account)

    captured = call_with_env "/#{slug}"

    assert_equal "/#{slug}", captured.fetch(:script_name)
    assert_equal "/", captured.fetch(:path_info)
  end

  test "detects the account UUID prefix when already in SCRIPT_NAME" do
    account = accounts(:initech)
    slug = AccountSlug.encode(account)

    captured = call_with_env "/boards", "SCRIPT_NAME" => "/#{slug}"

    assert_equal "/#{slug}", captured.fetch(:script_name)
    assert_equal "/boards", captured.fetch(:path_info)
    assert_equal account, captured.fetch(:current_account)
  end

  test "clears Current.account when no account prefix is present" do
    captured = call_with_env "/boards"

    assert_equal "", captured.fetch(:script_name)
    assert_equal "/boards", captured.fetch(:path_info)
    assert_nil captured.fetch(:account_id)
    assert_nil captured.fetch(:current_account)
  end

  test "encodes account as hyphenated UUID for URL" do
    account = accounts(:initech)
    encoded = AccountSlug.encode(account)
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i, encoded)
    assert_equal 36, encoded.length, "Hyphenated UUID is 32 hex chars + 4 hyphens"
  end

  test "decodes slug as string for lookup" do
    slug = "550e8400-e29b-41d4-a716-446655440000"
    assert_equal slug, AccountSlug.decode(slug)
  end

  test "does not treat legacy numeric prefix as account" do
    captured = call_with_env "/999888/boards"

    assert_equal "", captured.fetch(:script_name)
    assert_equal "/999888/boards", captured.fetch(:path_info)
    assert_nil captured.fetch(:account_id)
    assert_nil captured.fetch(:current_account)
    assert_equal 200, captured.fetch(:status), "No redirect; request is passed through and will 404 in Rails"
  end

  test "does not treat legacy base36 prefix as account" do
    account = accounts(:initech)
    base36_slug = account.id
    captured = call_with_env "/#{base36_slug}/boards"

    assert_equal "", captured.fetch(:script_name)
    assert_equal "/#{base36_slug}/boards", captured.fetch(:path_info)
    assert_nil captured.fetch(:account_id)
    assert_nil captured.fetch(:current_account)
    assert_equal 200, captured.fetch(:status), "No redirect; request is passed through and will 404 in Rails"
  end

  private
    def call_with_env(path, extra_env = {})
      captured = {}
      extra_env = { "action_dispatch.routes" => Rails.application.routes }.merge(extra_env)

      app = ->(env) do
        captured[:script_name] = env["SCRIPT_NAME"]
        captured[:path_info] = env["PATH_INFO"]
        captured[:account_id] = env["buzzy.account_id"]
        captured[:current_account] = Current.account
        [ 200, {}, [ "ok" ] ]
      end

      middleware = AccountSlug::Extractor.new(app)
      status, headers, _body = middleware.call Rack::MockRequest.env_for(path, extra_env.merge(method: "GET"))
      captured[:status] = status
      captured[:location] = headers["Location"]

      captured
    end
end
