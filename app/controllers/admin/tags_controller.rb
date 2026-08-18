class Admin::TagsController < Admin::BaseController
  def create
    taxonomy = Taxonomy.find(params[:tag][:taxonomy_id])
    @tag = taxonomy.tags.build(tag_params)
    if @tag.save
      redirect_to admin_taxonomy_path(taxonomy), notice: "Tag created."
    else
      @taxonomy = taxonomy
      render "admin/taxonomies/show", status: :unprocessable_entity
    end
  end

  def destroy
    @tag = Tag.find(params[:id])
    taxonomy = @tag.taxonomy
    @tag.destroy!
    redirect_to admin_taxonomy_path(taxonomy), notice: "Tag deleted."
  end

  private

  def tag_params
    params.require(:tag).permit(:name, :description)
  end
end
