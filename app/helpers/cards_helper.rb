module CardsHelper
  # 统一使用带 user 的路径（board.url_user），便于维护与单一入口
  def card_path_with_context(card, sub = nil, **options)
    user = card.board.url_user
    case sub
    when :watch then user_board_card_watch_path(user, card.board, card, **options)
    when :pin then user_board_card_pin_path(user, card.board, card, **options)
    when :edit_board then edit_user_board_card_board_path(user, card.board, card, **options)
    when :edit_column then edit_user_board_card_column_path(user, card.board, card, **options)
    when :new_tagging then new_user_board_card_tagging_path(user, card.board, card, **options)
    when :new_assignment then new_user_board_card_assignment_path(user, card.board, card, **options)
    else user_board_card_path(user, card.board, card, **options)
    end
  end

  # 仅传 card 时生成 pin 的路径（用于 my/pins 等无 board 上下文的页面）
  def card_pin_path(card, **options)
    card_path_with_context(card, :pin, **options)
  end

  def card_not_now_path(card, **options)
    user_board_card_not_now_path(card.board.url_user, card.board, card, **options)
  end

  def card_closure_path(card, **options)
    user_board_card_closure_path(card.board.url_user, card.board, card, **options)
  end

  def card_triage_path(card, **options)
    user_board_card_triage_path(card.board.url_user, card.board, card, **options)
  end

  def card_reading_path_for(card, **options)
    user_board_card_reading_path(card.board.url_user, card.board, card, **options)
  end

  def card_self_assignment_path(card, **options)
    user_board_card_self_assignment_path(card.board.url_user, card.board, card, **options)
  end

  def card_assignments_path(card, **options)
    user_board_card_assignments_path(card.board.url_user, card.board, card, **options)
  end

  def new_card_assignment_path(card)
    card_path_with_context(card, :new_assignment)
  end

  def card_image_path(card, **options)
    user_board_card_image_path(card.board.url_user, card.board, card, **options)
  end

  def card_goldness_path(card, **options)
    user_board_card_goldness_path(card.board.url_user, card.board, card, **options)
  end

  def card_publish_path(card, **options)
    user_board_card_publish_path(card.board.url_user, card.board, card, **options)
  end

  def card_taggings_path(card, **options)
    user_board_card_taggings_path(card.board.url_user, card.board, card, **options)
  end

  def card_steps_path(card, **options)
    user_board_card_steps_path(card.board.url_user, card.board, card, **options)
  end

  def card_reactions_path(card, **options)
    user_board_card_reactions_path(card.board.url_user, card.board, card, **options)
  end

  def new_card_reaction_path(card, **options)
    new_user_board_card_reaction_path(card.board.url_user, card.board, card, **options)
  end

  def card_comments_path(card, **options)
    user_board_card_comments_path(card.board.url_user, card.board, card, **options)
  end

  def card_comment_path(card, comment, **options)
    user_board_card_comment_path(card.board.url_user, card.board, card, comment, **options)
  end

  def edit_card_comment_path(card, comment, **options)
    edit_user_board_card_comment_path(card.board.url_user, card.board, card, comment, **options)
  end

  def card_step_path(card, step, **options)
    user_board_card_step_path(card.board.url_user, card.board, card, step, **options)
  end

  def edit_card_step_path(card, step, **options)
    edit_user_board_card_step_path(card.board.url_user, card.board, card, step, **options)
  end

  def card_board_path(card, **options)
    user_board_card_board_path(card.board.url_user, card.board, card, **options)
  end

  def card_article_tag(card, id: dom_id(card, :article), data: {}, **options, &block)
    classes = [
      options.delete(:class),
      ("golden-effect" if card.golden?),
      ("card--postponed" if card.postponed?),
      ("card--active" if card.active?)
    ].compact.join(" ")

    data[:drag_and_drop_top] = true if card.golden? && !card.closed? && !card.postponed?

    tag.article \
      id: id,
      style: "--card-color: #{card.color}; view-transition-name: #{id}",
      class: classes,
      data: data,
      **options,
      &block
  end

  def card_title_tag(card)
    title = [
      card.title,
      "added by #{card.creator.name}",
      "in #{card.board.name}"
    ]
    title << "assigned to #{card.assignees.map(&:name).to_sentence}" if card.assignees.any?
    title.join(" ")
  end

  def card_drafted_or_added(card)
    card.drafted? ? t("cards.drafted") : t("cards.added")
  end

  def card_social_tags(card)
    tag.meta(property: "og:title", content: "#{card.title} | #{card.board.name}") +
    tag.meta(property: "og:description", content: format_excerpt(card&.description, length: 200)) +
    tag.meta(property: "og:image", content: card.image.attached? ? "#{request.base_url}#{url_for(card.image)}" : "#{request.base_url}/opengraph.png") +
    tag.meta(property: "og:url", content: user_board_card_url(card.board.url_user, card.board, card))
  end

  def button_to_remove_card_image(card)
    button_to(card_image_path(card), method: :delete, class: "btn", data: { controller: "tooltip", action: "dialog#close" }) do
      icon_tag("trash") + tag.span(t("cards.remove_background_image"), class: "for-screen-reader")
    end
  end
end
