require "test_helper"

class ReactionTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "creating a comment reaction touches the card activity" do
    assert_changes -> { cards(:logo).reload.last_active_at } do
      comments(:logo_1).reactions.create!(content: "Nice!")
    end
  end

  test "reactions are deleted when comment is destroyed" do
    comment = comments(:logo_1)
    comment.reactions.create!(content: "👍")
    reaction_ids = comment.reactions.pluck(:id)

    assert reaction_ids.any?, "Expected comment to have reactions"

    comment.destroy

    assert_empty Reaction.where(id: reaction_ids)
  end

  test "creating a card reaction touches the card activity" do
    card = cards(:logo)

    assert_changes -> { card.reload.last_active_at } do
      card.reactions.create!(content: "🎉")
    end
  end

  test "reactions are deleted when card is destroyed" do
    card = cards(:logo)
    reaction_ids = card.reactions.pluck(:id)

    assert reaction_ids.any?, "Expected card to have reactions"

    card.destroy

    assert_empty Reaction.where(id: reaction_ids)
  end

  test "creating card reaction notifies card creator and not reacter" do
    card = cards(:logo)
    creator = card.creator
    reacter = users(:kevin)
    assert creator != reacter, "need different users for notification test"

    assert_enqueued_with(job: NotifyRecipientsJob) do
      card.reactions.create!(content: "👍", reacter: reacter)
    end

    perform_enqueued_jobs only: NotifyRecipientsJob
    notification = creator.notifications.where(source_type: "Reaction").last
    assert notification.present?, "card creator should receive reaction notification"
    assert_equal reacter, notification.creator
  end

  test "creating comment reaction notifies comment creator and not reacter" do
    comment = comments(:logo_agreement_jz)
    creator = comment.creator
    reacter = users(:kevin)
    assert creator != reacter, "need different users for notification test"

    assert_enqueued_with(job: NotifyRecipientsJob) do
      comment.reactions.create!(content: "👍", reacter: reacter)
    end

    perform_enqueued_jobs only: NotifyRecipientsJob
    notification = creator.notifications.where(source_type: "Reaction").last
    assert notification.present?, "comment creator should receive reaction notification"
    assert_equal reacter, notification.creator
  end

  test "creating reaction when reacter is owner does not create notification" do
    card = cards(:logo)
    creator = card.creator
    count_before = creator.notifications.where(source_type: "Reaction").count

    assert_enqueued_with(job: NotifyRecipientsJob) do
      card.reactions.create!(content: "👍", reacter: creator)
    end

    perform_enqueued_jobs only: NotifyRecipientsJob
    assert_equal count_before, creator.notifications.where(source_type: "Reaction").count,
      "owner should not receive notification for own content reaction"
  end
end
