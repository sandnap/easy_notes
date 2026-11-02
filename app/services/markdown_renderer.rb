# Renders note markdown to sanitized HTML for the preview pane.
class MarkdownRenderer
  ALLOWED_TAGS = %w[
    p br strong em del a ul ol li h1 h2 h3 h4 h5 h6
    blockquote pre code img hr table thead tbody tr th td
  ].freeze
  ALLOWED_ATTRIBUTES = %w[href src alt title class].freeze
  OPTIONS = {
    render: { unsafe: false },
    extension: {
      strikethrough: true,
      table: true,
      autolink: true,
      shortcodes: false,
      tasklist: false
    }
  }.freeze

  def self.render(markdown)
    new(markdown).render
  end

  def initialize(markdown)
    @markdown = markdown.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
  end

  def render
    html = Commonmarker.to_html(@markdown, options: OPTIONS, plugins: { syntax_highlighter: nil })
    Rails::HTML::SafeListSanitizer.new.sanitize(html, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES).to_s.html_safe
  end
end
