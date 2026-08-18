class Admin::RolesController < Admin::BaseController
  def index
    @roles = Role.chronological
  end

  def new
    @role = Role.new
  end

  def create
    @role = Role.new(role_params)
    if @role.save
      @role.replace_tags(parse_tags_input(params[:role][:tags_input]))
      redirect_to admin_roles_path, notice: "Role created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @role = find_record(Role.all, params[:id])
  end

  def update
    @role = find_record(Role.all, params[:id])
    if @role.update(role_params)
      @role.replace_tags(parse_tags_input(params[:role][:tags_input]))
      redirect_to admin_roles_path, notice: "Role updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @role = find_record(Role.all, params[:id])
    @role.destroy!
    redirect_to admin_roles_path, notice: "Role deleted."
  end

  private

  def role_params
    params.require(:role).permit(:title, :company, :summary, :body, :start_date, :end_date)
  end
end
