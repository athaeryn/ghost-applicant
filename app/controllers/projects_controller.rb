class ProjectsController < ApplicationController
  def index
    @projects = Project.featured
  end

  def show
    @project = Project.find_by!(slug: params[:id])
  end
end
