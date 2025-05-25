
# Kantan Register

シンプルな商品登録・在庫管理・AI画像認識レジ機能を備えたWebアプリケーションです。

---

## Overview

親しみやすく、誰でもすぐに使えるシンプルPOSシステム。  
Rails のフロントエンドと MySQL／PostgreSQL をバックエンドに、  
Flask サーバー（Python）＋SSIM（画像の形や明るさの類似度を比べる手法）による比較で、撮影画像と登録画像をマッチングします。

---


## 主な機能

| 機能                     | 説明                                                                 |
|--------------------------|----------------------------------------------------------------------|
| **商品管理**             | カタカナのみの名前制約、価格バリデーション                             |
| **画像アップロード**     | ActiveStorage ＋ カメラ撮影連携                                       |
| **AI画像認識レジ**       | Flask サーバー（Python）＋SSIM による類似度比較で撮影画像と商品画像をマッチング |
| **キーワード検索レジ**   | 商品名キーワード検索でカートに追加                                     |
| **カート管理**           | セッションベース、数量更新・クリア                                     |
| **売上分析ダッシュボード** | 年次／月次／日次切替の売上グラフとサマリー指標 (合計売上・オーダー数・平均購入額) |
| **Basic 認証**           | 管理画面は HTTP Basic 認証                                             |

---

## Live Demo

https://kantan-register.onrender.com  
_Basic 認証_  
- ユーザー名：`admin`  
- パスワード：`2222`  

---


## テクノロジー

### Rails サイド

- Ruby 3.2.0 / Rails 7.1.5  
- MySQL 8.0（開発）／PostgreSQL（本番）  
- Devise（ユーザー認証）  
- Sprockets / Turbo / Stimulus  
- ActiveStorage（画像管理、S3連携）  
- Groupdate（売上分析）  
- Chart.js（グラフ描画） 

※ Rails から Flask に画像を送る際、本番環境では `url_for(@product.image, host: "...")` でS3画像URLを生成し、Flask側で `requests.get(image_url)` を使って読み込み処理を行っています。

### Python（画像認識）サイド

- Python 3.10  
- Flask  
- Pillow  
- NumPy  
- scikit-image（SSIM: 構造類似度による画像類似判定）  
- gunicorn（本番用 WSGI）  
- Flask-CORS（CORS対応）  
- requests（画像URL取得）

#### `requirements.txt` 抜粋

```text
Flask==2.3.2
Pillow==10.3.0
numpy==1.26.4
scikit-image
gunicorn
Flask-CORS
requests==2.31.0
```

## 画面遷移
- **トップ** → 商品一覧 → 新規登録／編集
- **レジ画面** → カメラ認識 or キーワード → カート追加
- **カート画面** → 数量更新 → 会計
- **注文完了** → 履歴保存
- **売上分析** → 年次／月次／日次の切替

## データベース設計（一部）

### products テーブル
| Column      | Type     | Options                         |
|-------------|----------|---------------------------------|
| `name`      | string   | null: false, format: katakana   |
| `price`     | integer  | null: false, numericality: >0   |
| `created_at`| datetime |                                 |
| `updated_at`| datetime |                                 |


### orders / order_items テーブル
- `orders`      : 購入トランザクション  
- `order_items` : 商品×数量×価格の中間テーブル  

## 開発背景
- 小規模店舗やイベント出店での手軽な POS を目指して開発  
- Flask の軽量サーバーで画像認識を切り出し、Rails 側と疎結
- シンプルUIで高齢者にも扱いやすい構成を意識

## 使い方
1. **トップページ** → 商品登録  
2. **レジ画面** → 「撮影する」
3. 画像認識 or キーワードでカートに追加  
4. **会計** → 注文完了  
5. **売上分析** タブ切替 （グラフ表示で売上を可視化） 

## 今後の予定
- 在庫数アラート  
- 複数店舗対応  
- プッシュ通知（Web Push）  
- レスポンシブ改善／ダークモード  

## 制作時間
約 **80時間**

---