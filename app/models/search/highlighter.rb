class Search::Highlighter
  OPENING_MARK = "<mark class=\"circled-text\"><span></span>"
  CLOSING_MARK = "</mark>"
  ELIPSIS = "..."

  attr_reader :query

  def initialize(query)
    @query = query
  end

  def highlight(text)
    result = text.dup

    terms.each do |term|
      if cjk_term?(term)
        # CJK: no word boundaries, match substring as-is
        result.gsub!(/(#{Regexp.escape(term)})/i) { "#{OPENING_MARK}#{Regexp.last_match(1)}#{CLOSING_MARK}" }
      else
        result.gsub!(/\b(#{Regexp.escape(term)}\w*)\b/i) { "#{OPENING_MARK}#{Regexp.last_match(1)}#{CLOSING_MARK}" }
      end
    end

    escape_highlight_marks(result)
  end

  def snippet(text, max_words: 20)
    # Split by whitespace; CJK may be stored as space-separated chars so "日 本 語" → ["日", "本", "語"]
    words = text.split(/\s+/)
    match_index = words.index { |word| terms.any? { |term| word.downcase.include?(term.downcase) || (cjk_term?(term) && word.include?(term)) } }

    if words.length <= max_words
      highlight(text)
    elsif match_index
      start_index = [ 0, match_index - max_words / 2 ].max
      end_index = [ words.length - 1, start_index + max_words - 1 ].min

      snippet_text = words[start_index..end_index].join(" ")
      snippet_text = "...#{snippet_text}" if start_index > 0
      snippet_text = "#{snippet_text}..." if end_index < words.length - 1

      highlight(snippet_text)
    else
      text.truncate_words(max_words, omission: "...")
    end
  end

  private
    def cjk_term?(term)
      term.match?(/\p{Han}|\p{Hiragana}|\p{Katakana}|\p{Hangul}/)
    end

    def terms
      @terms ||= begin
        terms = []

        query.scan(/"([^"]+)"/) do |phrase|
          terms << phrase.first
        end

        unquoted = query.gsub(/"[^"]+"/, "")
        unquoted.split(/\s+/).each do |word|
          terms << word if word.present?
        end

        terms.uniq
      end
    end

    def escape_highlight_marks(html)
      CGI.escapeHTML(html)
        .gsub(CGI.escapeHTML(OPENING_MARK), OPENING_MARK.html_safe)
        .gsub(CGI.escapeHTML(CLOSING_MARK), CLOSING_MARK.html_safe)
        .html_safe
    end
end
