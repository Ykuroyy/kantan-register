# テーブル設計

## products テーブル

| Column | Type    | Options     |
| ------ | ------  | ----------- |
| name   | string  | null: false |
| price  | integer | null: false |
   ActiveStorageでimageを管理（カラム不要）

### Association

- has_many :order_items → 商品は複数の注文に含まれる可能性がある
- through :order_items で中間テーブル経由の orders を取得可能
- has_one_attached :image → 商品画像を保存（ActiveStorage）

## orders テーブル

| Column      | Type     | Options           |
| ----------- | -------- | ----------------- |
| total_price | integer  | null: false       |
| create_at   | datetime | 自動生成（記載不要） |

### Association

- has_many :order_items → 1件の注文には複数の商品が含まれる
- through :order_items → 間接的に複数 products と関係

## order_items テーブル

| Column     | Type       | Options                        |
| ---------- | ---------- | ------------------------------ |
| order_id   | references | null: false, foreign_key: true |
| product_id | references | null: false, foreign_key: true |
| quantity   | integer    | null: false                    |

### Association

- belongs_to → 中間テーブルなので、両方に属する


