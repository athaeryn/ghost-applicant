# Shared plumbing for the local, unauthenticated admin UI. Local hardware only —
# this is not exposed to the internet.
class Admin::BaseController < ApplicationController
  private

  def parse_tags_input(raw)
    raw.to_s.lines.map(&:strip).reject(&:blank?)
  end

  # Records use slugs in URLs (to_param); accept either an id or a slug.
  def find_record(scope, id)
    id.to_s.match?(/\A\d+\z/) ? scope.find_by(id: id.to_i) : scope.find_by(slug: id.to_s.parameterize)
  end
end
