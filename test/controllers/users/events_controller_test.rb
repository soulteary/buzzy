require "test_helper"

class Users::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show self" do
    get polymorphic_path([ users(:kevin), :events ])
    assert_in_body "What have you been up to?"
  end

  test "show other" do
    get polymorphic_path([ users(:david), :events ])
    assert_in_body "What has David been up to?"
  end
end
