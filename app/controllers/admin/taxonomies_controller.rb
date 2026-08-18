class Admin::TaxonomiesController < Admin::BaseController
  def index
    @taxonomies = Taxonomy.ordered.includes(:tags)
  end

  def new
    @taxonomy = Taxonomy.new
  end

  def create
    @taxonomy = Taxonomy.new(taxonomy_params)
    if @taxonomy.save
      redirect_to admin_taxonomies_path, notice: "Taxonomy created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @taxonomy = Taxonomy.includes(:tags).find(params[:id])
    @tag = Tag.new
  end

  def destroy
    @taxonomy = Taxonomy.find(params[:id])
    @taxonomy.destroy!
    redirect_to admin_taxonomies_path, notice: "Taxonomy deleted."
  end

  private

  def taxonomy_params
    params.require(:taxonomy).permit(:name, :description)
  end
end
