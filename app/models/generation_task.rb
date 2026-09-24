class GenerationTask < ApplicationRecord
  belongs_to :job_application
  belongs_to :application_draft, optional: true
  belongs_to :parent_draft, class_name: "ApplicationDraft", optional: true

  validates :generation_kind, presence: true

  scope :by_recent, -> { order(created_at: :desc) }

  def status_label
    if succeeded?
      "Succeeded"
    elsif error.present?
      "Failed"
    else
      "Running"
    end
  end

  def redraft?
    parent_draft_id.present?
  end

  def retryable?
    !succeeded?
  end

  # Clears the failed state and re-enqueues the same generation work so the
  # user doesn't have to retype feedback.
  def retry!
    update!(
      error: nil, model: nil, selection_json: nil,
      started_at: nil, finished_at: nil,
      succeeded: false, application_draft: nil
    )
    if redraft?
      RedraftGenerationJob.perform_later(generation_task_id: id)
    else
      ResumeGenerationJob.perform_later(generation_task_id: id)
    end
  end
end
