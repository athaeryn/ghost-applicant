class JobApplicationDraftsController < ApplicationController
  def show
    @job_application = JobApplication.find(params[:job_application_id])
    @draft = @job_application.application_drafts.find(params[:id])
    @drafts = @job_application.application_drafts.chronological.to_a
  end

  def toggle_favorite
    @job_application = JobApplication.find(params[:job_application_id])
    @draft = @job_application.application_drafts.find(params[:id])
    @draft.update!(favorited: !@draft.favorited)
    redirect_to job_application_draft_path(@job_application, @draft)
  end

  def redraft
    @job_application = JobApplication.find(params[:job_application_id])
    @draft = @job_application.application_drafts.find(params[:id])

    task = GenerationTask.create!(
      job_application: @job_application,
      kind: 0,
      generation_kind: @draft.kind == "cover_letter" ? 1 : 0,
      parent_draft: @draft,
      feedback: params[:general_feedback],
      selection_feedback: params[:selection_feedback]
    )
    RedraftGenerationJob.perform_later(generation_task_id: task.id)
    redirect_to job_application_path(@job_application), notice: "Redraft task queued."
  end

  def destroy
    @job_application = JobApplication.find(params[:job_application_id])
    @draft = @job_application.application_drafts.find(params[:id])
    @draft.destroy!
    redirect_to job_application_path(@job_application), notice: "Draft deleted."
  end
end
