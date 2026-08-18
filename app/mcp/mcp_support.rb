# Serialization + shared query helpers for the MCP tools.
module McpSupport
  RECORD_TYPES = { "post" => Post, "project" => Project, "role" => Role, "job_application" => JobApplication }.freeze

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

  # Resolves an array of ids-or-slugs to records; unknown entries are dropped.
  def resolve_records(scope, values)
    Array(values).filter_map { |v| find_record(scope, v) }
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
      tags: p.tag_list,
      project_ids: p.project_ids, role_ids: p.role_ids
    }
  end

  def project(p)
    {
      id: p.id, title: p.title, slug: p.slug, summary: p.summary,
      status: p.status, url: p.url,
      role_id: p.role_id, post_ids: p.post_ids,
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
      tags: r.tag_list,
      post_ids: r.post_ids, project_ids: r.project_ids
    }
  end

  def post_detail(p)
    post(p).merge(body: p.body.to_s)
  end

  def project_detail(p)
    project(p).merge(body: p.body.to_s)
  end

  def role_detail(r)
    role(r).merge(body: r.body.to_s)
  end

  def resume(g)
    {
      id: g.id, title: g.title, focus: g.focus, model: g.model,
      created_at: fmt_time(g.created_at), generated: g.body
    }
  end

  def job_application(j)
    {
      id: j.id, company: j.company, title: j.title, url: j.url,
      status: j.status, applied_at: fmt_date(j.applied_at),
      created_at: fmt_time(j.created_at), updated_at: fmt_time(j.updated_at),
      tags: j.tag_list, draft_count: j.application_drafts.count
    }
  end

  def job_application_detail(j)
    job_application(j).merge(
      description: j.description.to_s,
      notes: j.notes.to_s,
      drafts: j.application_drafts.chronological.map { |d| application_draft(d) }
    )
  end

  def application_draft(d)
    {
      id: d.id, kind: d.kind, label: d.label,
      body: d.body.to_s, created_at: fmt_time(d.created_at)
    }
  end
end
