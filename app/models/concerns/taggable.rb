module Taggable
  extend ActiveSupport::Concern

  included do
    has_many :taggings, as: :taggable, dependent: :destroy
    has_many :tags, through: :taggings
  end

  # Labels are "taxonomy:name" strings. Both taxonomies and tags are created
  # at runtime if they do not exist yet.
  def add_tags(*labels)
    Array(labels).flatten.compact.each do |label|
      tag = find_or_create_tag(label)
      taggings.find_or_create_by!(tag: tag)
    end
  end

  def replace_tags(labels)
    taggings.destroy_all
    add_tags(labels)
  end

  def remove_tag(label)
    tag = resolve_tag(label)
    taggings.where(tag: tag).destroy_all if tag
  end

  def tag_list
    tags.includes(:taxonomy).map(&:to_label).sort
  end

  def tags_by_taxonomy
    tags.includes(:taxonomy).group_by { |t| t.taxonomy.name }
        .transform_values { |ts| ts.map(&:name).sort }
  end

  private

  def find_or_create_tag(label)
    taxonomy_name, _, tag_name = label.to_s.strip.partition(":")
    return nil if tag_name.blank?

    taxonomy = Taxonomy.find_or_create_by!(name: taxonomy_name.strip)
    taxonomy.tags.find_or_create_by!(name: tag_name.strip)
  end

  def resolve_tag(label)
    taxonomy_name, _, tag_name = label.to_s.strip.partition(":")
    return nil if tag_name.blank?

    Tag.of_taxonomy(taxonomy_name.parameterize).find_by(name: tag_name.strip)
  end
end
