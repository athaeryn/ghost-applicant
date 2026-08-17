class Post < ApplicationRecord
  include Taggable

  validates :title, :body, presence: true
  validates :slug, presence: true

  before_validation :set_slug

  scope :published, -> { where.not(published_at: nil).where("published_at <= ?", Time.current) }
  scope :recent, -> { order(Arel.sql("COALESCE(posts.published_at, posts.created_at) DESC")) }

  def to_param
    slug
  end

  def published?
    published_at.present? && published_at <= Time.current
  end

  private

  def set_slug
    self.slug = title.parameterize if slug.blank? && title.present?
  end
end
