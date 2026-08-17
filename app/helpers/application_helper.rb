module ApplicationHelper
  def markdown(source)
    sanitize(MarkdownRenderer.render(source))
  end

  def human_date(date)
    date&.strftime("%b %Y")
  end

  def role_dates(role)
    [ human_date(role.start_date), role.end_date ? human_date(role.end_date) : "Present" ].join(" – ")
  end
end
