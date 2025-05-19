class Order < ApplicationRecord
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  # ❌ image に関係する処理は Order モデルには不要
  # after_commit :resize_image, on: [:create, :update]
end
