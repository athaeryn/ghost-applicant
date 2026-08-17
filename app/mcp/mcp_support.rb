# Serialization + shared query helpers for the MCP tools.
module McpSupport
  RECORD_TYPES = { "post" => Post, "project" => Project, "role" => Role }.freeze

  module_function

  def record_class(type)
    RECORD_TYPES[type.to_s.downcase]
  end

  # Finds a record by its integer id or slug within the given scope.
  def find_record(scope, id_or_slug)
    if id_or_slug.to_s.match?(/\A\d+\z/)
      scope.find_by(id: id_or_slug.to_i)
    else
      scope.find_by(slug: id_or_slug.to_s.parameterize)
    end
  end

  # "taxonomy:name" => ActiveRecord scope filtered to that tag.
  def with_tag(scope, label)
    taxonomy_name, _, tag_name = label.to_s.partition(":")
    return scope.none if tag_name.blank?

    scope.joins(taggings: { tag: :taxonomy }).where(
      taxonomies: { slug: taxonomy_name.parameterize },
      tags: { slug: tag_name.parameterize }
    )
  end

  # Parses "taxonomy:name" and returns [Taxonomy, Tag], creating both at runtime.
  def find_or_create_tag(label)
    taxonomy_name, _, tag_name = label.to_s.strip.partition(":")
    return nil if tag_name.blank?

    taxonomy = Taxonomy.find_or_create_by!(name: taxonomy_name.strip)
    taxonomy.tags.find_or_create_by!(name: tag_name.strip)
  end

  def fmt_time(time)
    time&.iso8601
  end

  def fmt_date(date)
    date&.iso8601
  end

  def date_range(start_date, end_date)
    [ fmt_date(start_date), fmt_date(end_date) ].compact.join(" to ")
  end

  def taxonomy(t)
    { id: t.id, name: t.name, slug: t.slug, description: t.description, tag_count: t.tags.count }
  end

  def tag(t)
    { id: t.id, taxonomy: t.taxonomy.name, name: t.name, slug: t.slug, description: t.description }
  end

  def post(p)
    {
      id: p.id, title: p.title, slug: p.slug, summary: p.summary,
      published: p.published?, published_at: fmt_time(p.published_at),
      created_at: fmt_time(p.created_at), updated_at: fmt_time(p.updated_at),
      tags: p.tag_list
    }
  end

  def project(p)
    {
      id: p.id, title: p.title, slug: p.slug, summary: p.summary,
      status: p.status, url: p.url,
      started_at: fmt_date(p.started_at), ended_at: fmt_date(p.ended_at),
      created_at: fmt_time(p.created_at), updated_at: fmt_time(p.updated_at),
      tags: p.tag_list
    }
  end

  def role(r)
    {
      id: r.id, title: r.title, company: r.company, slug: r.slug, summary: r.summary,
      start_date: fmt_date(r.start_date), end_date: fmt_date(r.end_date),
      created_at: fmt_time(r.created_at), updated_at: fmt_time(r.updated_at),
      tags: r.tag_list
    }
  end

  def resume(g)
    {
      id: g.id, title: g.title, focus: g.focus, model: g.model,
      created_at: fmt_time(g.created_at), generated: g.body
    }
  end
end
