require "test_helper"

class User::AttachableTest < ActiveSupport::TestCase
  test "attachable_plain_text_representation is normalized mention handle" do
    assert_equal "@david", users(:david).attachable_plain_text_representation
    assert_equal "@jz", users(:jz).attachable_plain_text_representation
  end
end
