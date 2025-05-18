class Product < ApplicationRecord
  has_one_attached :image
  has_many :order_items

  validates :name, presence: true, length: { maximum: 40 }

  validates :price, presence: true,
                    numericality: {
                      only_integer: true,
                      greater_than: 0,
                      less_than_or_equal_to: 9_999_999
                    }
end
