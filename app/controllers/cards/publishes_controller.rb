class Cards::PublishesController < ApplicationController
  include CardScoped

  def create
    @card.publish

    if add_another_param?
      card = @board.cards.create!(status: :drafted)
      redirect_to user_board_card_draft_path(@board.url_user, @board, card), notice: I18n.t("cards.card_added")
    else
      redirect_to @card.board
    end
  end

  private
    def add_another_param?
      params[:creation_type] == "add_another"
    end
end
