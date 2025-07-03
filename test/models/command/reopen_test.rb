require "test_helper"

class Command::ReopenTest < ActionDispatch::IntegrationTest
  include CommandTestHelper

  setup do
    Current.session = sessions(:david)
    @card = cards(:text)
    @card.close(user: users(:david))
  end

  test "reopen card on perma" do
    assert_changes -> { @card.reload.open? }, from: false, to: true do
      execute_command "/reopen", context_url: collection_card_url(@card.collection, @card)
    end

    assert_nil @card.closed_by
  end

  test "reopen cards on cards' index page" do
    cards = cards(:logo, :text, :layout)
    cards.each { |card| card.close }

    execute_command "/reopen", context_url: collection_cards_url(@card.collection, indexed_by: "closed")

    assert cards.map(&:reload).all?(&:open?)
  end

  test "undo reopen" do
    cards = cards(:logo, :text, :layout)
    cards.each { |card| card.close(user: users(:david)) }

    command = parse_command "/reopen", context_url: collection_cards_url(@card.collection, indexed_by: "closed")
    command.execute

    assert cards.map(&:reload).all?(&:open?)

    command.undo

    assert cards.map(&:reload).all?(&:closed?)
  end
end
