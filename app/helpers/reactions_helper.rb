module ReactionsHelper
  # 统一使用带 user 的路径（board.url_user），与 CardsHelper 一致
  def reaction_path_prefix_for(reactable)
    case reactable
    when Card then [ reactable.board.url_user, reactable.board, reactable ]
    when Comment then [ reactable.card.board.url_user, reactable.card.board, reactable.card, reactable ]
    else
      raise ArgumentError, "Unknown reactable type: #{reactable.class}"
    end
  end
end
