# frozen_string_literal: true

require "test_helper"

module ActionText
  class MentionResolverTest < ActiveSupport::TestCase
    setup do
      @user = users(:kevin)
    end

    test "resolve_user returns User when node has valid sgid" do
      node = { "sgid" => @user.attachable_sgid, "content-type" => "application/vnd.actiontext.mention" }
      assert_equal @user, MentionResolver.resolve_user(node)
    end

    test "resolve_user returns User when node has valid gid only" do
      node = { "gid" => @user.to_global_id.to_s }
      assert_equal @user, MentionResolver.resolve_user(node)
    end

    test "resolve_user falls back to gid when sgid is invalid" do
      node = { "sgid" => "invalid-sgid", "gid" => @user.to_global_id.to_s }
      assert_equal @user, MentionResolver.resolve_user(node)
    end

    test "resolve_user accepts sgid without ActionText purpose" do
      node = { "sgid" => @user.to_sgid.to_s }
      assert_equal @user, MentionResolver.resolve_user(node)
    end

    test "resolve_user returns nil when both sgid and gid are invalid" do
      node = { "sgid" => "invalid", "gid" => "gid://buzzy/User/999999" }
      assert_nil MentionResolver.resolve_user(node)
    end

    test "resolve_user returns nil when node is nil" do
      assert_nil MentionResolver.resolve_user(nil)
    end

    test "resolve_user returns nil when node is blank" do
      assert_nil MentionResolver.resolve_user({})
    end

    test "resolve_user returns nil when gid points to non-User (e.g. Tag)" do
      tag = tags(:web)
      node = { "gid" => tag.to_global_id.to_s }
      assert_nil MentionResolver.resolve_user(node)
    end

    test "resolve_user prefers sgid over gid when both are valid" do
      other_user = users(:david)
      node = { "sgid" => @user.attachable_sgid, "gid" => other_user.to_global_id.to_s }
      assert_equal @user, MentionResolver.resolve_user(node)
    end

    test "resolve_user returns User when node has user_id" do
      node = { "user_id" => @user.id.to_s }
      assert_equal @user, MentionResolver.resolve_user(node)
    end

    test "resolve_user returns User when node has id" do
      node = { "id" => @user.id.to_s }
      assert_equal @user, MentionResolver.resolve_user(node)
    end

    test "resolve_user falls back to user_id when sgid and gid are invalid" do
      node = { "sgid" => "invalid", "gid" => "gid://buzzy/User/999999", "user_id" => @user.id.to_s }
      assert_equal @user, MentionResolver.resolve_user(node)
    end

    test "resolve_user returns nil when user_id is non-existent" do
      node = { "user_id" => "999999" }
      assert_nil MentionResolver.resolve_user(node)
    end

    test "resolve_user returns User when node has handle (email prefix)" do
      node = { "handle" => @user.mention_handle }
      assert_equal @user, MentionResolver.resolve_user(node)
    end

    test "resolve_user returns User when node has data-handle" do
      node = { "data-handle" => @user.mention_handle }
      assert_equal @user, MentionResolver.resolve_user(node)
    end

    test "resolve_user returns nil when handle does not match any identity" do
      node = { "handle" => "nonexistent-prefix-123" }
      assert_nil MentionResolver.resolve_user(node)
    end
  end
end
