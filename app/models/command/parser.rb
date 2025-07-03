class Command::Parser
  attr_reader :context

  delegate :user, :cards, :filter, to: :context

  def initialize(context)
    @context = context
  end

  def parse(string)
    parse_command(string).tap do |command|
      command.user = user
      command.line ||= as_plain_text(string)
      command.context ||= context
    end
  end

  private
    def as_plain_text_with_attachable_references(string)
      ActionText::Content.new(string).render_attachments(&:to_gid).fragment.to_plain_text
    end

    def as_plain_text(string)
      ActionText::Content.new(string).to_plain_text
    end

    def parse_command(string)
      rich_text_command = as_plain_text_with_attachable_references(string)
      plain_text_command = as_plain_text(string)

      parse_plain_text_command(plain_text_command) || parse_rich_text_command(rich_text_command)
    end

    def parse_plain_text_command(string)
      command_name, *_ = string.strip.split(" ")

      case command_name
      when /^#/
        Command::FilterByTag.new(tag_title: tag_title_from(string), params: filter.as_params)
      when /^@/
        Command::GoToUser.new(user_id: context.find_user(command_name)&.id)
      end
    end

    def parse_rich_text_command(string)
      command_name, *command_arguments = string.strip.split(" ")
      combined_arguments = command_arguments.join(" ")

      case command_name
      when "/user"
        Command::GoToUser.new(user_id: context.find_user(combined_arguments)&.id)
      when "/assign", "/assignto"
        Command::Assign.new(assignee_ids: assignees_from(command_arguments).collect(&:id), card_ids: cards.ids)
      when "/clear"
        Command::ClearFilters.new(params: filter.as_params)
      when "/close"
        Command::Close.new(card_ids: cards.ids, reason: combined_arguments)
      when "/reopen"
        Command::Reopen.new(card_ids: cards.ids)
      when "/consider", "/reconsider"
        Command::Consider.new(card_ids: cards.ids)
      when "/do"
        Command::Do.new(card_ids: cards.ids)
      when "/insight"
        Command::GetInsight.new(query: combined_arguments, card_ids: cards.ids)
      when "/add_card"
        Command::AddCard.new(card_title: combined_arguments, collection_id: guess_collection&.id)
      when "/search"
        Command::Search.new(terms: combined_arguments)
      when "/stage"
        Command::Stage.new(stage_id: context.find_workflow_stage(combined_arguments)&.id, card_ids: cards.ids)
      when "/visit"
        Command::VisitUrl.new(url: command_arguments.first)
      when "/tag"
        Command::Tag.new(tag_title: tag_title_from(combined_arguments), card_ids: cards.ids)
      else
        parse_free_string(string)
      end
    end

    def assignees_from(strings)
      Array(strings).filter_map do |string|
        context.find_user(string)
      end
    end

    def guess_collection
      cards.first&.collection || Collection.first
    end

    def tag_title_from(string)
      context.find_tag(string)&.title || string.gsub(/^#/, "")
    end

    def parse_free_string(string)
      if cards = multiple_cards_from(string)
        Command::FilterCards.new(card_ids: cards.ids, params: filter.as_params)
      elsif card = single_card_from(string)
        Command::GoToCard.new(card_id: card.id)
      else
        Command::Ai::Parser.new(context).parse(string)
      end
    end

    def multiple_cards_from(string)
      if string.match?(/^[\d\s,]+$/)
        tokens = string.split(/[\s,]+/)
        user.accessible_cards.where(id: tokens).presence if tokens&.many?
      end
    end

    def single_card_from(string)
      user.accessible_cards.find_by_id(string)
    end
end
