class Product < ApplicationRecord
  has_one_attached :image
  # has_many :order_items, dependent: :restrict_with_error
  has_many :order_items, dependent: :nullify

  before_validation :normalize_blank_price_and_name

  VALID_KATAKANA_REGEX = /\A[ァ-ヶー－]+\z/

  # ── 商品名のバリデーション ──
  validates :name,
            presence: { message: "を入力してください" },
            length: { maximum: 40 },
            format: { with: VALID_KATAKANA_REGEX, message: "はカタカナのみで入力してください" }

  # ── 金額は必須チェックだけ先に書く ──
  validates :price,
            presence: { message: "を入力してください" }

  # ── 金額の数値チェックは「空欄ならスキップ」 ──
  validates :price,
            numericality: {
              only_integer: true,
              greater_than: 0,
              less_than_or_equal_to: 9_999_999
            },
            allow_blank: true

  private

  def normalize_blank_price_and_name
    self.name  = nil if name.blank?
    self.price = nil if price.blank?
  end
end
