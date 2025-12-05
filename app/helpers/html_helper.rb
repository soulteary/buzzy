module HtmlHelper
  def format_html(html)
    fragment = Nokogiri::HTML.fragment(html)

    auto_link(fragment)

    fragment.to_html.html_safe
  end

  private
    EXCLUDED_ELEMENTS = %w[ a figcaption pre code ]
    EMAIL_AUTOLINK_REGEXP = /\b[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\b/
    URL_REGEXP = URI::DEFAULT_PARSER.make_regexp(%w[http https])

    def auto_link(fragment)
      fragment.traverse do |node|
        next unless auto_linkable_node?(node)

        content = node.text
        linked_content = content.dup

        auto_link_urls(linked_content)
        auto_link_emails(linked_content)

        if linked_content != content
          node.replace(Nokogiri::HTML.fragment(linked_content))
        end
      end
    end

    def auto_linkable_node?(node)
      node.text? && node.ancestors.none? { |ancestor| EXCLUDED_ELEMENTS.include?(ancestor.name) }
    end

    def auto_link_urls(linked_content)
      linked_content.gsub!(URL_REGEXP) do |match|
        url, trailing_punct = extract_url_and_punctuation(match)
        %(<a href="#{url}" rel="noreferrer">#{url}</a>#{trailing_punct})
      end
    end

    def extract_url_and_punctuation(url_match)
      if url_match.end_with?(".", "?", ",", ":")
        [ url_match[..-2], url_match[-1] ]
      else
        [ url_match, "" ]
      end
    end

    def auto_link_emails(text)
      text.gsub!(EMAIL_AUTOLINK_REGEXP) do |match|
        %(<a href="mailto:#{match}">#{match}</a>)
      end
    end
end
