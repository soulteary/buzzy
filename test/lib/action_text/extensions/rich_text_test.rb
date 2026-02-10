require "test_helper"
require "cgi"

module ActionText
  module Extensions
    class RichTextTest < ActiveSupport::TestCase
      setup do
        @user = users(:kevin)
        @tag = tags(:web)
        @card = boards(:writebook).cards.create!(title: "RichText private methods", description: "<p>Hello</p>")
        @rich_text = @card.description
      end

      test "mention_node? is true when content-type is mention" do
        node = { "content-type" => "application/vnd.actiontext.mention" }

        assert @rich_text.send(:mention_node?, node)
      end

      test "mention_node? is true when sgid decodes to user" do
        node = { "content-type" => "application/octet-stream", "sgid" => @user.attachable_sgid }

        assert @rich_text.send(:mention_node?, node)
      end

      test "mention_node? is false when sgid does not decode to user and type is not mention" do
        node = { "content-type" => "application/octet-stream", "sgid" => @tag.attachable_sgid }

        assert_not @rich_text.send(:mention_node?, node)
      end

      test "sgid_decodes_to_user? returns true for user sgid" do
        node = { "sgid" => @user.attachable_sgid }

        assert @rich_text.send(:sgid_decodes_to_user?, node)
      end

      test "sgid_decodes_to_user? returns false for non-user sgid" do
        node = { "sgid" => @tag.attachable_sgid }

        assert_not @rich_text.send(:sgid_decodes_to_user?, node)
      end

      test "infer_mention_user_from_content extracts user id from escaped img src" do
        raw = CGI.escapeHTML(%(<img src="/users/#{@user.id}/avatar" />))

        assert_equal @user, @rich_text.send(:infer_mention_user_from_content, raw)
      end

      test "infer_mention_user_from_content handles quoted escaped html payload" do
        raw = %("#{CGI.escapeHTML(%(<img src="/users/#{@user.id}/avatar" />))}")

        assert_equal @user, @rich_text.send(:infer_mention_user_from_content, raw)
      end

      test "infer_mention_user_from_content returns nil for invalid content" do
        assert_nil @rich_text.send(:infer_mention_user_from_content, "not-a-valid-mention")
      end
    end
  end
end
