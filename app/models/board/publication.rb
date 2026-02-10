class Board::Publication < ApplicationRecord
  belongs_to :account, default: -> { board.account }
  belongs_to :board

  before_create :generate_key, if: -> { key.blank? }

  private
    def generate_key
      self.key = ActiveRecord::Type::Uuid.generate
    end
end
