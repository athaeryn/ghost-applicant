class ApplicationDraft < ApplicationRecord
  belongs_to :job_application

  KINDS = %w[resume cover_letter].freeze

  validates :kind, inclusion: { in: KINDS }
  validates :body, presence: true

  scope :resumes, -> { where(kind: "resume") }
  scope :cover_letters, -> { where(kind: "cover_letter") }
  scope :chronological, -> { order(created_at: :asc) }
end
