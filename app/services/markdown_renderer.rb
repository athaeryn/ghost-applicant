# Renders Markdown (CommonMark / GFM) to safe HTML for the blog and portfolio.
class MarkdownRenderer
  def self.render(source)
    Commonmarker.to_html(
      source.to_s,
      options: { extension: { table: true, strikethrough: true, autolink: true, tagfilter: true } }
    )
  end
end
