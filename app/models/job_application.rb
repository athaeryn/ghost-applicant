class JobApplication < ApplicationRecord
  include Taggable

  has_many :application_drafts, dependent: :destroy

  STATUSES = %w[saved applied interviewing offer rejected archived].freeze

  validates :status, inclusion: { in: STATUSES }
  validate :at_least_one_descriptive_field

  before_validation :set_defaults

  scope :by_recent, -> { order(created_at: :desc) }

  def label
    parts = [ title, company.presence && "at #{company}", url.presence ]
    parts.compact.join(" ").presence || "Untitled application"
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
