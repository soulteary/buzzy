module HtmlHelper
  # Markdown 输出允许的标签与属性（用于个人介绍等，白名单 + Redcarpet::Render::Safe 双重防护 XSS）
  MARKDOWN_SANITIZE_TAGS = %w[ p br strong em b i a ul ol li code pre h1 h2 h3 h4 h5 h6 blockquote hr table thead tbody tr th td ].freeze
  MARKDOWN_SANITIZE_ATTRIBUTES = { "a" => %w[ href rel ] }.freeze

  # 个人介绍仅允许段落、换行、加粗、斜体（无列表、代码、链接等）
  MARKDOWN_BIO_SANITIZE_TAGS = %w[ p br strong em b i ].freeze

  # 个人介绍用 Markdown 渲染器：仅保留加粗、斜体、段落、换行；列表等不渲染为列表
  class BioMarkdownRenderer < Redcarpet::Render::Safe
    def initialize(**options)
      super({ hard_wrap: true }.merge(options))
    end

    def list(body, list_type)
      body
    end

    def list_item(text, list_type)
      text.present? ? "<p>#{text}</p>" : ""
    end

    def block_code(code, language)
      ERB::Util.html_escape(code)
    end

    def codespan(code)
      ERB::Util.html_escape(code)
    end

    def header(text, level)
      "<p>#{text}</p>"
    end

    def table(header, body)
      ""
    end

    def tablerow(content)
      ""
    end

    def tablecell(content, alignment)
      ""
    end

    def block_quote(quote)
      quote
    end

    def link(link, title, content)
      content
    end

    def autolink(link, link_type)
      ERB::Util.html_escape(link)
    end

    def hrule
      ""
    end
  end

  def format_html(html)
    Loofah::HTML5::DocumentFragment.parse(html).scrub!(AutoLinkScrubber.new).to_html.html_safe
  end

  # 将 Markdown 转为 HTML（用于用户个人介绍等）
  # 防护：1) Redcarpet::Render::Safe 转义源内 HTML、仅安全链接 2) sanitize 白名单标签/属性，纵深防御
  def render_markdown(text)
    return "" if text.blank?

    renderer = Redcarpet::Render::Safe.new(hard_wrap: true)
    markdown = Redcarpet::Markdown.new(renderer, autolink: true, tables: true, fenced_code_blocks: true)
    raw_html = markdown.render(text.to_s)
    sanitized = sanitize(raw_html, tags: MARKDOWN_SANITIZE_TAGS, attributes: MARKDOWN_SANITIZE_ATTRIBUTES)
    format_html(sanitized)
  end

  # 个人介绍专用：仅支持加粗、斜体，不支持列表、代码块、链接等
  def render_markdown_bio(text)
    return "" if text.blank?

    renderer = BioMarkdownRenderer.new
    markdown = Redcarpet::Markdown.new(renderer, autolink: false, tables: false, fenced_code_blocks: false)
    raw_html = markdown.render(text.to_s)
    sanitized = sanitize(raw_html, tags: MARKDOWN_BIO_SANITIZE_TAGS, attributes: {})
    format_html(sanitized)
  end
end
