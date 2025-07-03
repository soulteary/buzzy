class Prompts::CommandsController < ApplicationController
  def index
    @commands = [
      [ "/add_card", "Add a new card", "/add_card " ],
      [ "/assign", "Assign cards to people", "/assign @" ],
      [ "/close", "Close cards (with optional reason)", "/close " ],
      [ "/reopen", "Reopen cards", "/reopen" ],
      [ "/clear", "Clear all filters", "/clear" ],
      [ "/consider", "Move cards back to Considering", "/consider" ],
      [ "/do", "Move cards to Doing", "/do" ],
      [ "/reconsider", "Move cards back to Considering", "/reconsider" ],
      [ "/search", "Search cards and comments", "/search " ],
      [ "/tag", "Tag selected cards", "/tag #" ],
      [ "/stage", "Move cards to a Workflow Stage", "/stage " ],
      [ "/help", "Show help menu", "/help" ]
    ]

    if stale? etag: @commands
      render layout: false
    end
  end
end
