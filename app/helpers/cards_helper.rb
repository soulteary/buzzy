module CardsHelper
  def cards_next_page_link(target, page:, filter:, fetch_on_visible: false, data: {}, **options)
    url = cards_previews_path(target: target, page: page.next_param, **filter.as_params)

    if fetch_on_visible
      data[:controller] = "#{data[:controller]} fetch-on-visible"
      data[:fetch_on_visible_url_value] = url
    end

    link_to "Load more",
      url,
      id: "#{target}-load-page-#{page.next_param}",
      data: { turbo_stream: true, **data },
      class: "btn txt-small",
      **options
  end

  def card_article_tag(card, id: dom_id(card, :article), **options, &block)
    classes = [
      options.delete(:class),
      ("card--golden" if card.golden?),
      ("card--doing" if card.doing?),
      ("card--drafted" if card.drafted?)
    ].compact.join(" ")

    tag.article \
      id: id,
      style: "--card-color: #{card.color}; view-transition-name: #{id}",
      class: classes,
      **options,
      &block
  end

  def button_to_delete_card(card)
    button_to collection_card_path(card.collection, card),
        method: :delete, class: "btn txt-negative borderless txt-small", data: { turbo_frame: "_top", turbo_confirm: "Are you sure you want to permanently delete this card?" } do
      concat(icon_tag("trash"))
      concat(tag.span("Delete this card"))
    end
  end

  def card_title_tag(card)
    title = [
      card.title,
      "added by #{card.creator.name}",
      "in #{card.collection.name}"
    ]
    title << "assigned to #{card.assignees.map(&:name).to_sentence}" if card.assignees.any?
    title.join(" ")
  end

  def card_entropy_action(card)
    if card.doing?
      "Falls Back"
    elsif card.considering?
      "Closes"
    end
  end

  def cacheable_preview_parts_for(card)
    [ card, card.collection.workflow, card.collection.entropy_configuration ]
  end
end
