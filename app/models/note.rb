class Note < ApplicationRecord
  belongs_to :category, counter_cache: true

  validates :title, presence: true
  validates :content, presence: true
  validates :position, presence: true

  has_rich_text :content

  before_validation :set_default_position, on: :create

  private

  def set_default_position
    self.position ||= (category.notes.maximum(:position) || 0) + 1
  end
end
