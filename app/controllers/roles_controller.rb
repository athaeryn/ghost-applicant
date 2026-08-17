class RolesController < ApplicationController
  def index
    @roles = Role.chronological
  end

  def show
    @role = Role.find_by!(slug: params[:id])
  end
end
