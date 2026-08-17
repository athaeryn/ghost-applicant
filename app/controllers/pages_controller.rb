class PagesController < ApplicationController
  def home
    @posts = Post.published.recent.limit(3)
    @projects = Project.featured.limit(6)
    @roles = Role.chronological.limit(8)
    @taxonomies = Taxonomy.ordered.includes(:tags).to_a
  end
end
