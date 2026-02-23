module MarkdownHelper
  EXTENSIONS = {
    autolink: true,
    tables: true,
    fenced_code_blocks: true,
    strikethrough: true,
    no_intra_emphasis: true,
    space_after_headers: true
  }.freeze

  RENDER_OPTIONS = {
    hard_wrap: true,
    escape_html: true,
    link_attributes: { target: "_blank", rel: "noopener noreferrer" }
  }.freeze

  def render_markdown(text)
    self.class.to_html(text)
  end

  def self.to_html(text)
    return "" if text.blank?

    renderer = Redcarpet::Render::HTML.new(**RENDER_OPTIONS)
    markdown = Redcarpet::Markdown.new(renderer, **EXTENSIONS)
    markdown.render(text)
  end
end
