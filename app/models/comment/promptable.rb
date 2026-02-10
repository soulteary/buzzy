module Comment::Promptable
  extend ActiveSupport::Concern

  included do
    include Rails.application.routes.url_helpers
  end

  def to_prompt
    <<~PROMPT
        BEGIN OF COMMENT #{id}

        **Content:**

        #{body.to_plain_text.first(5000)}

        #### Metadata

        * Id: #{id}
        * Card id: #{card.number}
        * Card title: #{card.title}
        * Created by: #{creator.name}}
        * Created at: #{created_at}}
        * Path: #{Rails.application.routes.url_helpers.user_board_card_path(card.board.url_user, card.board, card, anchor: ActionView::RecordIdentifier.dom_id(self))}
        END OF COMMENT #{id}
      PROMPT
  end
end
