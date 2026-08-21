class Admin::JobApplicationsController < Admin::BaseController
  def index
    @job_applications = JobApplication.by_recent
  end

  def new
    @job_application = JobApplication.new
  end

  def create
    @job_application = JobApplication.new(job_application_params)
    if @job_application.save
      @job_application.replace_tags(parse_tags_input(params[:job_application][:tags_input]))
      redirect_to job_application_path(@job_application), notice: "Job application created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @job_application = JobApplication.find(params[:id])
  end

  def edit
    @job_application = JobApplication.find(params[:id])
  end

  def update
    @job_application = JobApplication.find(params[:id])
    if @job_application.update(job_application_params)
      @job_application.replace_tags(parse_tags_input(params[:job_application][:tags_input]))
      redirect_to job_application_path(@job_application), notice: "Job application updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @job_application = JobApplication.find(params[:id])
    @job_application.destroy!
    redirect_to admin_job_applications_path, notice: "Job application deleted."
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

  private

  def job_application_params
    params.require(:job_application).permit(:company, :title, :url, :description, :notes, :status, :applied_at, :gap_tags)
  end
end
