require "test_helper"

class Notifier::EventNotifierTest < ActiveSupport::TestCase
  test "for returns the matching notifier class for the mention" do
    assert_kind_of Notifier::MentionNotifier, Notifier.for(mentions(:logo_card_david_mention_by_jz))
  end

  test "notify the mentionee" do
    users(:kevin).mentioned_by(users(:david), at: cards(:logo))

    assert_no_difference -> { users(:kevin).notifications.count } do
      Notifier.for(mentions(:logo_card_david_mention_by_jz)).notify
    end
  end

  test "create notifications for mentionee" do
    assert_no_difference -> { users(:david).notifications.count } do
      Notifier.for(events(:layout_commented)).notify
    end
  end

  test "don't create notifications for self-mentions" do
    assert_no_difference -> { users(:jz).notifications.count } do
      Notifier.for(events(:layout_commented)).notify
    end
  end
end
