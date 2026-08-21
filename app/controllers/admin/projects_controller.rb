class Admin::ProjectsController < Admin::BaseController
  def index
    @projects = Project.featured
  end

  def new
    @project = Project.new(role_id: params.dig(:project, :role_id))
  end

  def create
    @project = Project.new(project_params)
    if @project.save
      @project.replace_tags(parse_tags_input(params[:project][:tags_input]))
      redirect_to project_path(@project), notice: "Project created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @project = find_record(Project.all, params[:id])
  end

  def update
    @project = find_record(Project.all, params[:id])
    if @project.update(project_params)
      @project.replace_tags(parse_tags_input(params[:project][:tags_input]))
      redirect_to project_path(@project), notice: "Project updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project = find_record(Project.all, params[:id])
    @project.destroy!
    redirect_to admin_projects_path, notice: "Project deleted."
  end

  private

  def project_params
    params.require(:project).permit(:title, :summary, :body, :url, :status, :role_id, :started_at, :ended_at)
  end
end
