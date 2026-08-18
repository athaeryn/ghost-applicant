class Admin::PostsController < Admin::BaseController
  def index
    @posts = Post.recent
  end

  def new
    @post = Post.new
  end

  def create
    @post = Post.new(post_params)
    apply_published_toggle(@post)
    if @post.save
      @post.replace_tags(parse_tags_input(params[:post][:tags_input]))
      redirect_to admin_posts_path, notice: "Post created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @post = find_record(Post.all, params[:id])
  end

  def update
    @post = find_record(Post.all, params[:id])
    apply_published_toggle(@post)
    if @post.update(post_params)
      @post.replace_tags(parse_tags_input(params[:post][:tags_input]))
      redirect_to admin_posts_path, notice: "Post updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post = find_record(Post.all, params[:id])
    @post.destroy!
    redirect_to admin_posts_path, notice: "Post deleted."
  end

  private

  def post_params
    params.require(:post).permit(:title, :summary, :body)
  end

  def apply_published_toggle(post)
    if params[:post][:published] == "1"
      post.published_at ||= Time.current
    else
      post.published_at = nil
    end
  end
end
