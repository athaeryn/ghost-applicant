class JobApplication < ApplicationRecord
  include Taggable

  has_many :application_drafts, dependent: :destroy

  STATUSES = %w[saved applied interviewing offer rejected archived].freeze

  validates :status, inclusion: { in: STATUSES }
  validate :at_least_one_descriptive_field

  before_validation :set_defaults

  scope :by_recent, -> { order(created_at: :desc) }

  def label
    parts = [ title, company.presence && "at #{company}" ]
    parts.compact.join(" ").presence || url.presence || "Untitled application"
  end

  def has_favorited_resume_draft
    application_drafts.resumes.where(favorited: true).exists?
  end

  def has_favorited_cover_letter_draft
    application_drafts.cover_letters.where(favorited: true).exists?
  end

  private

  def at_least_one_descriptive_field
    return if [ company, title, description ].any?(&:present?)

    errors.add(:base, "Add a company, title, or description")
  end

  def set_defaults
    self.status = "saved" if status.blank?
  end
end
