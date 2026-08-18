class JobApplicationDraftsController < ApplicationController
  def show
    @job_application = JobApplication.find(params[:job_application_id])
    @draft = @job_application.application_drafts.find(params[:id])
    @drafts = @job_application.application_drafts.chronological.to_a
  end
end
