class Command::Parser
  attr_reader :context

  delegate :user, :cards, :filter, to: :context

  def initialize(context)
    @context = context
  end

  def parse(string)
    command_name, *command_arguments = string.strip.split(" ")

    case command_name
    when "/assign", "/assignto"
      Command::Assign.new(assignee_ids: assignees_from(command_arguments).collect(&:id), card_ids: cards.ids)
    when /^@/
      Command::GoToUser.new(user_id: assignee_from(command_name)&.id)
    else
      search(string)
    end
  end

  private
    def assignees_from(strings)
      Array(strings).filter_map do |string|
        assignee_from(string)
      end
    end

    # TODO: This is temporary as it can be ambiguous. We should inject the user ID in the command
    #   under the hood instead, as determined by the user picker. E.g: @1234.
    def assignee_from(string)
      string_without_at = string.delete_prefix("@")
      User.all.find { |user| user.mentionable_handles.include?(string_without_at) }
    end

    def search(string)
      if card = user.accessible_cards.find_by_id(string)
        Command::GoToCard.new(card_id: card.id)
      else
        Command::Search.new(query: string, params: filter.as_params)
      end
    end
end
