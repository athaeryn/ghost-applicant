class Tag < ApplicationRecord
  belongs_to :taxonomy
  has_many :taggings, dependent: :destroy

  validates :name, presence: true,
                   uniqueness: { scope: :taxonomy_id, case_sensitive: false }
  validates :slug, presence: true,
                   uniqueness: { scope: :taxonomy_id }

  before_validation :set_slug

  scope :of_taxonomy, ->(slug) { joins(:taxonomy).where(taxonomies: { slug: slug }) }
  scope :ordered, -> { joins(:taxonomy).order("taxonomies.name, tags.name") }

  def to_label
    "#{taxonomy.name}:#{name}"
  end

  private

  def set_slug
    self.name = name.to_s.strip if name
    self.slug = name.parameterize if slug.blank? && name.present?
  end
end
