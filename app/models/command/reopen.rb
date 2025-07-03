class Command::Reopen < Command
  include Command::Cards

  store_accessor :data, :reopened_card_ids

  def title
    "Reopen #{cards_description}"
  end

  def execute
    reopened_card_ids = []

    transaction do
      cards.find_each do |card|
        reopened_card_ids << card.id
        card.reopen(user: user)
      end

      update! reopened_card_ids: reopened_card_ids
    end
  end

  def undo
    transaction do
      reopened_cards.find_each do |card|
        card.close(user: user)
      end
    end
  end

  private
    def reopened_cards
      user.accessible_cards.where(id: reopened_card_ids)
    end
end
