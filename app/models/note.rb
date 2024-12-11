class Note < ApplicationRecord
  belongs_to :category, counter_cache: true

  validates :title, presence: true
  validates :content, presence: true
end
