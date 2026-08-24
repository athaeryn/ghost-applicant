class JobApplicationQuote < ApplicationRecord
  belongs_to :job_application
  belongs_to :source, polymorphic: true, optional: true

  validates :body, presence: true

  scope :chronological, -> { order(created_at: :asc) }

  def source_label
    return "Manual" unless source
    case source
    when Role then "#{source.title} at #{source.company}"
    when Project then source.title
    else source.class.name
    end
  end
end
