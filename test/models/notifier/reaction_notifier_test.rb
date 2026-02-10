require "test_helper"

class Notifier::ReactionNotifierTest < ActiveSupport::TestCase
  test "for returns ReactionNotifier for Reaction source" do
    reaction = reactions(:logo_card_david)
    assert_kind_of Notifier::ReactionNotifier, Notifier.for(reaction)
  end

  test "card reaction notifies card creator and excludes reacter" do
    # logo card creator is david; logo_card_kevin is kevin reacting to logo card
    reaction = reactions(:logo_card_kevin)
    assert_equal users(:kevin), reaction.reacter
    assert_equal users(:david), reaction.reactable.creator

    notifications = Notifier.for(reaction).notify

    assert_equal [ users(:david) ], notifications.map(&:user)
    assert_equal users(:kevin), notifications.first.creator
  end

  test "card reaction does not notify when reacter is card creator" do
    # logo_card_david: david reacts to logo card (david is card creator)
    reaction = reactions(:logo_card_david)
    assert_equal users(:david), reaction.reacter
    assert_equal users(:david), reaction.reactable.creator

    notifications = Notifier.for(reaction).notify

    assert_empty notifications
  end

  test "comment reaction notifies comment creator and excludes reacter" do
    # logo_agreement_jz comment creator is jz; kevin reaction notifies jz
    reaction = reactions(:kevin)
    assert_equal users(:kevin), reaction.reacter
    assert_equal users(:jz), reaction.reactable.creator

    notifications = Notifier.for(reaction).notify

    assert_equal [ users(:jz) ], notifications.map(&:user)
    assert_equal users(:kevin), notifications.first.creator
  end

  test "comment reaction also notifies same identity users in other accounts" do
    comment = comments(:logo_agreement_jz)
    other_account_user = User.create!(
      name: "JZ Other Account",
      role: :member,
      identity: users(:jz).identity,
      account: accounts(:initech),
      verified_at: Time.current
    )
    reaction = comment.reactions.create!(content: "👍", reacter: users(:kevin))

    notifications = Notifier.for(reaction).notify

    assert_equal [ users(:jz), other_account_user ].sort_by(&:id), notifications.map(&:user).sort_by(&:id)
    assert notifications.all? { |n| n.creator == users(:kevin) }
  end

  test "comment reaction does not notify when reacter is comment creator" do
    # david reaction on logo_agreement_jz (comment creator is jz, reacter is david - still notify jz)
    # So we need a reaction where reacter is comment creator: create one
    comment = comments(:logo_agreement_jz)
    reaction = comment.reactions.create!(content: "👍", reacter: users(:jz))

    notifications = Notifier.for(reaction).notify

    assert_empty notifications
  end
end
