class Admin::DashboardController < Admin::BaseController
  def index
    @posts = Post.recent.limit(5)
    @projects = Project.featured.limit(5)
    @roles = Role.chronological.limit(5)
    @job_applications = JobApplication.by_recent.limit(5)
    @taxonomies = Taxonomy.ordered
  end
end
