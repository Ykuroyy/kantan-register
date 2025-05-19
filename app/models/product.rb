class Product < ApplicationRecord
  has_one_attached :image
  has_many :order_items

  VALID_KATAKANA_REGEX = /\A[ァ-ヶー－]+\z/

  validates :name,
            presence: true,
            length: { maximum: 40 },
            format: { with: VALID_KATAKANA_REGEX, message: "はカタカナのみで入力してください" }

  validates :price,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than: 0,
              less_than_or_equal_to: 9_999_999
            }

  def resize_image
    return unless image.attached?
    image.variant(resize_to_limit: [500, 500]).processed
  end
end
