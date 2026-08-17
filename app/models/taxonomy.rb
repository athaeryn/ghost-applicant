class Taxonomy < ApplicationRecord
  has_many :tags, dependent: :destroy

  validates :name, presence: true,
                   uniqueness: { case_sensitive: false }
  validates :slug, presence: true

  before_validation :set_slug

  scope :ordered, -> { order(:name) }

  private

  def set_slug
    self.name = name.to_s.strip if name
    self.slug = name.parameterize if slug.blank? && name.present?
  end
end
