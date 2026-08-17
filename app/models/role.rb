class Role < ApplicationRecord
  include Taggable

  validates :title, :company, presence: true
  validates :slug, presence: true

  before_validation :set_slug

  scope :chronological, -> { order(Arel.sql("COALESCE(roles.start_date, roles.end_date, roles.created_at) DESC")) }

  def to_param
    slug
  end

  private

  def set_slug
    self.slug = "#{company}-#{title}".parameterize if slug.blank? && company.present? && title.present?
  end
end
