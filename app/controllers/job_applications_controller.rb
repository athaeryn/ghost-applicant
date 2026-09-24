class JobApplicationsController < ApplicationController
  def index
    @job_applications = JobApplication.by_recent
  end

  def show
    @job_application = JobApplication.find(params[:id])
  end

  def preview
    @job_application = JobApplication.find(params[:id])
    generator = ResumeGenerator.new
    kind = params[:kind] || "resume"
    @selection = begin
      generator.select_records(@job_application, kind: kind)
    rescue LmStudioError
      { selected: [], notes: "", fallback: true }
    end
    @system_prompt, @user_prompt = generator.preview_prompt(@job_application, kind: kind, selection: @selection)
  end

  def analyze
    @job_application = JobApplication.find(params[:id])
    generator = ResumeGenerator.new
    result = generator.analyze(@job_application)

    @job_application.update!(gap_tags: result[:gap_tags].join("\n"))
    @job_application.add_tags(result[:tags]) if result[:tags].any?

    redirect_to job_application_path(@job_application), notice: "Analysis complete. #{result[:tags].count} tags applied."
  rescue LmStudioUnavailableError, LmStudioError => e
    redirect_to job_application_path(@job_application), alert: "Analysis failed: #{e.message}"
  end

  def draft
    @job_application = JobApplication.find(params[:id])
    task = GenerationTask.create!(
      job_application: @job_application,
      kind: 0,
      generation_kind: 0,
      focus: params[:focus]
    )
    ResumeGenerationJob.perform_later(generation_task_id: task.id)
    redirect_to job_application_path(@job_application), notice: "Resume generation task queued."
  end

  def draft_cover_letter
    @job_application = JobApplication.find(params[:id])
    task = GenerationTask.create!(
      job_application: @job_application,
      kind: 0,
      generation_kind: 1,
      focus: params[:focus]
    )
    ResumeGenerationJob.perform_later(generation_task_id: task.id)
    redirect_to job_application_path(@job_application), notice: "Cover letter generation task queued."
  end

  def add_tag
    @job_application = JobApplication.find(params[:id])
    @job_application.add_tags(params[:tag])
    redirect_to job_application_path(@job_application)
  end

  def remove_tag
    @job_application = JobApplication.find(params[:id])
    @job_application.remove_tag(params[:tag])
    redirect_to job_application_path(@job_application)
  end
end
