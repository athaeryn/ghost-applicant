class Admin::GenerationTasksController < Admin::BaseController
  def index
    @generation_tasks = GenerationTask.by_recent.limit(50)
  end

  def show
    @generation_task = GenerationTask.find(params[:id])
  end

  def retry
    @generation_task = GenerationTask.find(params[:id])
    @generation_task.retry!
    redirect_to admin_generation_task_path(@generation_task), notice: "Generation task requeued."
  rescue StandardError => e
    redirect_to admin_generation_task_path(@generation_task), alert: "Could not retry: #{e.message}"
  end
end
