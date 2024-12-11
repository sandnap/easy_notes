class Category < ApplicationRecord
  belongs_to :user
  has_many :notes, dependent: :destroy

  validates :name, presence: true, 
                  uniqueness: { scope: :user_id, case_sensitive: false }
end
