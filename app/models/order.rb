class Order < ApplicationRecord
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items


  # リサイズ付きバリデーションまたはアップロード処理
  after_commit :resize_image, on: [:create, :update]

  private

  def resize_image
    return unless image.attached?

    image.variant(resize_to_limit: [500, 500]).processed
  end
end

