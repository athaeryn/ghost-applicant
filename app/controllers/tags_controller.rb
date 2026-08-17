class TagsController < ApplicationController
  def index
    @taxonomy = Taxonomy.includes(:tags).find_by!(slug: params[:taxonomy])
  end

  def show
    @tag = Tag.of_taxonomy(params[:taxonomy]).find_by!(slug: params[:slug])
    @posts = Post.published.joins(:taggings).where(taggings: { tag: @tag }).recent
    @projects = Project.joins(:taggings).where(taggings: { tag: @tag }).featured
    @roles = Role.joins(:taggings).where(taggings: { tag: @tag }).chronological
  end
end
