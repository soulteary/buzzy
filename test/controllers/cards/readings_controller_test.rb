require "test_helper"

class Cards::ReadingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    freeze_time

    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: false, to: true do
      assert_changes -> { accesses(:writebook_kevin).reload.accessed_at }, from: nil, to: Time.current do
        post board_card_reading_url(boards(:writebook), cards(:logo)), as: :turbo_stream
      end
    end

    assert_response :success
  end

  test "read one notification on card visit" do
    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: false, to: true do
      post board_card_reading_path(boards(:writebook), cards(:logo)), as: :turbo_stream
    end

    assert_response :success
  end

  test "read multiple notifications on card visit" do
    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: false, to: true do
      assert_changes -> { notifications(:logo_assignment_kevin).reload.read? }, from: false, to: true do
        post board_card_reading_path(boards(:writebook), cards(:logo)), as: :turbo_stream
      end
    end

    assert_response :success
  end

  test "destroy" do
    freeze_time

    notifications(:logo_published_kevin).read
    notifications(:logo_assignment_kevin).read

    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: true, to: false do
      assert_changes -> { accesses(:writebook_kevin).reload.accessed_at }, to: Time.current do
        delete board_card_reading_url(boards(:writebook), cards(:logo)), as: :turbo_stream
      end
    end

    assert_response :success
  end

  test "unread one notification on destroy" do
    notifications(:logo_published_kevin).read

    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: true, to: false do
      delete board_card_reading_path(boards(:writebook), cards(:logo)), as: :turbo_stream
    end

    assert_response :success
  end

  test "unread multiple notifications on destroy" do
    notifications(:logo_published_kevin).read
    notifications(:logo_assignment_kevin).read

    assert_changes -> { notifications(:logo_published_kevin).reload.read? }, from: true, to: false do
      assert_changes -> { notifications(:logo_assignment_kevin).reload.read? }, from: true, to: false do
        delete board_card_reading_path(boards(:writebook), cards(:logo)), as: :turbo_stream
      end
    end

    assert_response :success
  end
end
