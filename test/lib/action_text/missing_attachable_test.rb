require "test_helper"

module ActionText
  class MissingAttachableTest < ActiveSupport::TestCase
    test "initialize accepts nil sgid" do
      missing = Attachables::MissingAttachable.new(nil)

      assert_equal I18n.t("users.missing_attachable_label"), missing.attachable_plain_text_representation
    end

    test "initialize accepts blank sgid" do
      missing = Attachables::MissingAttachable.new("")

      assert_equal I18n.t("users.missing_attachable_label"), missing.attachable_plain_text_representation
    end
  end
end
