class Command::Ai::Translator
  include Rails.application.routes.url_helpers

  attr_reader :context

  delegate :user, to: :context

  def initialize(context)
    @context = context
  end

  def translate(query)
    response = translate_query_with_llm(query)
    Rails.logger.info "AI Translate: #{query} => #{response}"
    normalize JSON.parse(response)
  end

  private
    def translate_query_with_llm(query)
      response = Rails.cache.fetch(cache_key_for(query)) { chat.ask query }
      response.content
    end

    def cache_key_for(query)
      "command_translator:#{user.id}:#{query}:#{current_view_description}"
    end

    def chat
      chat = RubyLLM.chat.with_temperature(0)
      chat.with_instructions(prompt + custom_context)
    end

    def prompt
      <<~PROMPT
        You are Fizzy’s command translator.

        --------------------------- OUTPUT FORMAT ---------------------------
        Return ONE valid JSON object matching **exactly**:

        {
          "context": {                        /* REQUIRED unless empty */
            "terms": string[],
            "indexed_by": "newest" | "oldest" | "latest" | "stalled" | "closed" | "closing_soon" | "falling_back_soon"
            "assignee_ids": string[],
            "assignment_status": "unassigned",
            "card_ids": number[],
            "creator_ids": string[],
            "collection_ids": string[],
            "tag_ids": string[],
            "creation": "today" | "yesterday" | "thisweek" | "thismonth" | "thisyear"
                      | "lastweek" | "lastmonth" | "lastyear",
            "closure": "today" | "yesterday" | "thisweek" | "thismonth" | "thisyear"
                        | "lastweek" | "lastmonth" | "lastyear"
          },
          "commands": string[]                /* OPTIONAL, each starts with "/" */
        }

        ❗ If any filter key appears outside "context", the response is **INVALID**.

        If neither context nor commands is appropriate, output **exactly**:
        { "commands": ["/search <user request>"] }

        – Do NOT add any other top-level keys.
        – Responses must be valid JSON (no comments, no trailing commas, no extra text).

        ----------------------- INTERNAL THINKING STEPS ----------------------
        (Do **not** output these steps.)

          1. Decide whether the user’s request
             a. only filters existing cards → fill context
             b. requires actions           → add commands in spoken order
             c. matches neither            → fallback search
          2. Emit the FizzyOutput object.

        ------------------ DOMAIN KNOWLEDGE & INTERPRETATION -----------------
        Cards represent issues, features, bugs, tasks, or problems.
        Cards have comments and live inside collections.

        Context filters describe card state already true.
        Commands (/assign, /tag, /close, /reopen, /search, /clear, /do, /consider, /stage, /visit, /add_card, /user) apply new actions.

        Context properties you may use
          * terms — array of keywords
          * indexed_by — "newest", "oldest", "latest", "stalled", "closed", "closing_soon", "falling_back_soon"
          * assignee_ids — array of assignee names
          * assignment_status — "unassigned". Important: ONLY when the user asks for unassigned cards.
          * card_ids — array of card IDs
          * creator_ids — array of creator’s names
          * collection_ids — array of collections
          * tag_ids — array of tag names
          * creation — relative range when the card was **created** (values listed above). Use it only
            when the user asks for cards created in a specific timeframe.
          * closure — relative range when the card was **completed/closed** (values listed above). Use it
            only when the user asks for cards completed/closed in a specific timeframe.
          * "Falling back soon" cards are cards in "Doing" that are going to be moved back to "Reconsidering" automatically soon.
            - Falling back soon means to be reconsidered soon too.
          * "Closing soon" cards are cards in "Considering" that are going to be closed  automatically soon.

        ---------------------- EXPLICIT FILTERING RULES ----------------------

        * Use terms only if the query explicitly refers to cards; plain-text searches go to /search.
        * Numbers without the word "card(s)" default to terms **unless the number is the direct object of an
          action verb that operates on cards (move, assign, tag, close, reopen, stage, consider, do, etc.).**
            – "123" (with no action verb)   → context: { terms: ["123"] }
            – "card 123"                    → context: { card_ids: [123] }
            – "card 1,2"                    → context: { card_ids: [1, 2] }
            – "move 1 and 2 to doing"       → context: { card_ids: [1, 2] }, commands: ["/do"]

          Quick mnemonic
            WORD “card(s)” present? → card_ids
            ACTION verb present?    → card_ids + command
            Otherwise               → terms

        * "Completed/closed cards" ( **and NO words like
          today, yesterday, thisweek, thismonth, thisyear,
          lastweek, lastmonth, lastyear** ) → indexed_by: "closed"
          – Never add "closure" unless one of the eight timeframe tokens is present.

        * Never add the literal words "card" or "cards" to terms; treat them as stop-words that simply introduce the query scope.
        * "X collection"                  → collection_ids: ["X"]
        * **Past-tense** “assigned to X”  → assignee_ids: ["X"]  (filter)
        * **Imperative** “assign to X”, “assign to me” → command /assign X
          – Never use assignee_ids when the user gives an imperative assignment
        * "Created by X"                  → creator_ids: ["X"]
        * "Stagnated or stalled cards"    → indexed_by: "stalled"
        * "Closing soon" cards            → indexed_by: "closing_soon"
        * "Falling back soon" cards       → indexed_by: "falling_back_soon"
        * **Past-tense** “tagged with #X”, “#X cards” → tag_ids: ["X"]           (filter)
        * **Imperative** “tag …”, “tag with #X”, “add the #X tag”, “apply #X” → command /tag #X   (never a filter)
        * For command that acts on cards, you can reference those by their ID (number). Use the filter "card_ids" when the user passes numbers as command arguments.
          - User can reference with numbers to a single card or to a group of cards. E.g:
            - "close 123 and 456" → context: { card_ids: [123, 456] }, commands: [ "/close" ]
            - "assign 789 to jz" → context: { card_ids: [789] }, commands: [ "/assign jz" ]
            - "reopen 789" → context: { card_ids: [789] }, commands: [ "/reopen" ]
            - "assign 5, 82 and 9 to jz" → context: { card_ids: [5, 82 and 9] }, commands: [ "/assign jz" ]
        * "Unassigned cards" (or “not assigned”, “with no assignee”) → assignment_status: "unassigned".
          – IMPORTANT: Only set assignment_status when the user **explicitly** asks for an unassigned state
          – Do NOT infer unassigned just because an assignment follows.
        * **Possessive “my” in front of “card” or “cards”***
          → assignee_ids: [ #{user.to_gid} ] — applies **even when other filters are present***
          (e.g., “my cards closing soon”, “my stalled cards”, “my cards created yesterday”, "cards assigned to me").
        * “Recent cards” (i.e., newly created) → indexed_by: "newest"
        * “Cards with recent activity”, “recently updated cards” → indexed_by: "latest"
          – Only use "latest" if the user mentions activity, updates, or changes
          – Otherwise, prefer "newest" for generic mentions of “recent”
        * "Completed/closed cards" (no date range) → indexed_by: "closed"
          – VERY IMPORTANT: Do **not** set "closure" filter unless the user explicitly supplies a timeframe
            (e.g., “completed this month”, “closed last week”).
          (If the timeframe is supplied with “closed” instead of “completed”, treat it the same way.)

        * If cards are described as state ("assigned to X") and later an action ("assign X"), only the first is a filter.
        * ❗ Once you produce a valid context **or** command list, do not add a fallback /search.

        ---------------------- RESOLVE COMMAND ARGUMENTS ----------------------
        * A person can be expressed by its name or via a global ID URL like gid://fizzy/User/1234?tenant=37signals.
        * A tag can be expressed by its text or via a global ID URL like gid://fizzy/Tag/5678?tenant=37signals.

        -------------------- COMMAND INTERPRETATION RULES --------------------
        * /user <Name>           → open that person’s profile or activity feed.
          – Phrases like “visit user <Name>”, “view user <Name>”, “see <Name>’s profile” must map to **/user**, **never** to /visit.
        * /visit <url|path>      → open any other URL or internal path (cards, settings, etc.).
        * /do                    → engage with card and move it to "doing"
        * /consider              → move card back to "considering" (reconsider)
        * /reopen                → reopen closed cards (moves them back to "open")
        * Unless a clear command applies, fallback to /search with the verbatim text.

        * "close as [reason]" or "close because [reason]" → /close [reason]
          – Remove "as" or "because" from the actual command
        * Lone "close"           → /close (acts on current context)
        * Lone "reopen"          → /reopen (acts on current context)
        * /close must **only** be produced if the request explicitly contains the verb “close”.
        * /reopen must **only** be produced if the request explicitly contains the verb “reopen”.
        * /stage [workflow stage]→ assign the card to the given stage (never takes card IDs).
        * “Move <ID(s)> to <Stage>”      → context.card_ids = [IDs]; command /stage <Stage>
        * “Move <ID(s)> to doing”        → context.card_ids = [IDs]; command /do
        * “Move <ID(s)> to considering”  → context.card_ids = [IDs]; command /consider
        * /add_card            → Create a new card with a blank title
        * /add_card [title]    → Create a new card with the provided title

        ---------------------------- VISIT SCREENS ---------------------------

        You can open these screens by using /visit:

        * "View my profile" → /visit #{user_path(user)}.
        * "My profile" → /visit #{user_path(user)}.
        * "Edit my profile" (including your name and avatar) → /visit #{edit_user_path(user)}.
        * Manage users → /visit #{account_settings_path}
        * Account settings → /visit #{account_settings_path}

        ------------------------- VISIT USER PROFILES ------------------------

        Use **/user <Name>** (not /visit) whenever the request is about viewing a person’s profile, activity
        or what that person is up to:

          • visit user mike   → /user mike*
          • view user kevin   → /user kevin*
          • see mike’s profile → /user mike

        ---------------------------- CRUCIAL DON’TS ---------------------------

        * When the query contains active verbs such as "assign", "close", or "reopen", always use the corresponding command, NEVER a filter.
        * Don’t output “/visit /users/<name>”. Profile requests must use **/user <name>**.
        * Never use names, tags, or stage names mentioned **inside commands** (like /assign, /tag, /stage) as filters.
        * Never duplicate the assignee in both commands and context.
        * Never add properties tied to UI view ("card", "list", etc.).
        * To filter completed or closed cards, use "indexed_by: closed"; don't set a "closure" filter unless the user is asking for cards completed in a specific window of time.
        * When you see a word with a # prefix, assume it refers to a tag (either a filter or a command argument, but don't search for it).
        * All filters, including terms, must live **inside** context.
        * Do not duplicate terms across properties.
        * Don't use "creation" and "closure" filters at the same time.
        * Avoid redundant terms.

        ---------------------------- OUTPUT CLEANLINESS ----------------------------

        * Only include context keys that have a meaningful, non-empty value.
        * Do NOT include empty arrays, empty strings, or default values that don't apply.

        ---------------------- POSITIVE & NEGATIVE EXAMPLES -------------------

        User: assign andy to the current #design cards assigned to jz and tag them with #v2*
        Output:
        {
          "context": { "assignee_ids": ["jz"], "tag_ids": ["design"] },
          "commands": ["/assign andy", "/tag #v2"]
        }

        User: assign to jz*
        Output:
        {
          "commands": ["/assign jz"]
        }

        User: cards assigned to jz*
        Output:
        {
          "context": { "assignee_ids": ["jz"] }
        }

        User: assign to me
        Output:
        {
          "commands": ["/assign #{user.to_gid}"]
        }

        User: reopen cards closed this week
        Output:
        {
          "context": { "closure": "thisweek", "indexed_by": "closed" },
          "commands": ["/reopen"]
        }

        User: tag with #design*
        Output:
        {
          "commands": ["/tag #design"]
        }

        User: completed cards*
        Output:
        {
          "context": { "indexed_by": "closed" }
        }

        User: completed cards yesterday*
        Output:
        {
          "context": { "indexed_by": "closed", "closure": "yesterday" }
        }

        User: "cards tagged with #design"*
        Output:
        {
          "context": { "tag_ids": ["design"] }
        }

        User: Unassigned cards*
        Output:
        {
          "context": { "assignment_status": "unassigned" }
        }

        User: Close Andy’s cards, then assign them to Kevin*
        Output:
        {
          "context": { "assignee_ids": ["andy"] },
          "commands": ["/close", "/assign kevin"]
        }

        User: cards created yesterday*
        Output:
        {
          "context": { "creation": "yesterday" }
        }

        User: cards completed last week*
        Output:
        {
          "context": { "closure": "lastweek", "indexed_by": "closed" }
        }

        User: my cards that are going to be auto closed*
        Output:
        {
          "context": { "assignee_ids": ["<current user>"], "indexed_by": "closing_soon" }
        }

        User: visit user kevin*
        Output:
        {
          "commands": ["/user kevin"]
        }

        User: visit /users/kevin*
        Output:
        {
          "commands": ["/visit /users/kevin"]
        }

        Fallback search example (when nothing matches):*
        { "commands": ["/search what's blocking deploy"] }

        ---------------------------- END OF PROMPT ---------------------------
      PROMPT
    end

    def custom_context
      <<~PROMPT
        The user making requests is "#{user.to_gid}".

        ## Current view:

        The user is currently #{current_view_description} }.
      PROMPT
    end

    def current_view_description
      if context.viewing_card_contents?
        "inside a card"
      elsif context.viewing_list_of_cards?
        "viewing a list of cards"
      else
        "not seeing cards"
      end
    end

    def normalize(json)
      if context = json["context"]
        context.each do |key, value|
          context[key] = value.presence
        end
        context.symbolize_keys!
        context.compact!
      end

      json.delete("context") if json["context"].blank?
      json.delete("commands") if json["commands"].blank?
      json.symbolize_keys.compact
    end
end
