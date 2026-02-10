module Search::Stemmer
  extend self

  STEMMER = Mittens::Stemmer.new

  # Unicode letter/number for query sanitization; CJK character classes for tokenization
  CJK_RANGE = "\\p{Han}\\p{Hiragana}\\p{Katakana}\\p{Hangul}".freeze

  def stem(value)
    return value if value.blank?

    # Keep letters, numbers, spaces (Unicode-aware)
    cleaned = value.gsub(/[^\p{L}\p{N}\p{M}\s]/, " ")
    # CJK: insert space between each character so FTS5 can index per-character (e.g. "日本語" → "日 本 語")
    tokenized = cleaned.gsub(/([#{CJK_RANGE}])/, ' \1').strip
    tokenized.split(/\s+/).map { |word| stem_token(word) }.join(" ")
  end

  # For MySQL ngram FULLTEXT: do not insert space between CJK chars, so ngram (e.g. n=2)
  # tokenizes "卡片" as "卡片" and can match. stem() inserts spaces for SQLite FTS5.
  def stem_for_ngram(value)
    return value if value.blank?

    cleaned = value.gsub(/[^\p{L}\p{N}\p{M}\s]/, " ")
    cleaned.split(/\s+/).map { |word| stem_token(word) }.join(" ").strip.presence || value
  end

  def stem_token(word)
    return word if word.blank?
    # CJK or other non-ASCII: keep as-is (already space-separated if CJK)
    return word unless word.match?(/\A[a-zA-Z]+\z/)
    STEMMER.stem(word.downcase)
  end
end
