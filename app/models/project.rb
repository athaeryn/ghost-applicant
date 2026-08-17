class Project < ApplicationRecord
  include Taggable

  STATUSES = %w[active completed shelved].freeze

  validates :title, :body, presence: true
  validates :slug, presence: true
  validates :status, inclusion: { in: STATUSES }

  before_validation :set_slug

  scope :featured, -> { order(Arel.sql("COALESCE(projects.started_at, projects.created_at) DESC")) }

  def to_param
    slug
  end

  private

  def set_slug
    self.status = "active" if status.blank?
    self.slug = title.parameterize if slug.blank? && title.present?
  end
end
