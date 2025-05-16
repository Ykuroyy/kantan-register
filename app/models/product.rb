class Product < ApplicationRecord
  has_one_attached :image
  has_many :order_items
  
  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
