class Role < ApplicationRecord
  include Taggable

  has_and_belongs_to_many :posts
  has_many :projects, dependent: :nullify

  validates :title, :company, presence: true
  validates :slug, presence: true

  before_validation :set_slug

  scope :chronological, -> { order(Arel.sql("COALESCE(roles.start_date, roles.end_date, roles.created_at) DESC")) }

  def to_param
    slug
  end

  def display_name
    "#{title} at #{company}"
  end

  private

  def set_slug
    self.slug = "#{company}-#{title}".parameterize if slug.blank? && company.present? && title.present?
  end
end
