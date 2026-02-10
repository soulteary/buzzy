module CommentsHelper
  def new_comment_placeholder(card)
    if card.creator == Current.user && card.comments.empty?
      t("cards.first_comment_placeholder")
    else
      t("cards.comment_placeholder")
    end
  end
end
