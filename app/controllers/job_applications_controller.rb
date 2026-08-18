class JobApplicationsController < ApplicationController
  def index
    @job_applications = JobApplication.by_recent
  end

  def show
    @job_application = JobApplication.find(params[:id])
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
