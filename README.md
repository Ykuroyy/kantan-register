
# Kantan Register

シンプルな商品登録・在庫管理・AI画像認識レジ機能を備えたWebアプリケーションです。

---

## Overview

親しみやすく、誰でもすぐに使えるシンプルPOSシステム。  
Rails のフロントエンドと MySQL／PostgreSQL をバックエンドに、  
画像認識部分は Flask＋SSIM を Python で実装しています。

---

## 主な機能

| 機能                 | 説明                                                                 |
|----------------------|----------------------------------------------------------------------|
| **商品管理**         | カタカナのみの名前制約、価格バリデーション                             |
| **画像アップロード** | ActiveStorage ＋ カメラ撮影連携                                       |
| **AI画像認識レジ**   | Flask サーバー（Python）＋SSIM で撮影画像を商品にマッチ               |
| **キーワード検索レジ**| 商品名キーワード検索でカートに追加                                     |
| **カート管理**       | セッションベース、数量更新・クリア                                     |
| **売上分析ダッシュボード** | 年次／月次／日次切替の売上グラフとサマリー指標 (合計売上・オーダー数・平均購入額) |
| **Basic 認証**       | 管理画面は HTTP Basic 認証                                             |

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
- ActiveStorage（画像管理）  
- Groupdate（売上分析）  
- Chart.js（グラフ描画）  

### Python（画像認識）サイド

- Python 3.10  
- Flask  
- Pillow  
- NumPy  
- scikit-image（SSIM: 構造類似度計算）  
- gunicorn（本番用 WSGI）  

#### `requirements.txt` 抜粋

```text
Flask>=2.3
Pillow>=9.0
numpy>=1.24
scikit-image>=0.20
gunicorn>=20.1

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

### users テーブル
| Column             | Type    | Options                         |
|--------------------|---------|---------------------------------|
| `email`            | string  | null: false, unique: true       |
| `encrypted_password` | string| null: false                     |
| `role`             | integer | default: 0 (管理者／一般)        |

### orders / order_items テーブル
- `orders`      : 購入トランザクション  
- `order_items` : 商品×数量×価格の中間テーブル  

## 開発背景
- 小規模店舗やイベント出店での手軽な POS を目指して開発  
- Flask の軽量サーバーで画像認識を切り出し、Rails 側と疎結合  

## 使い方
1. **トップページ** → 商品登録  
2. **レジ画面** → 「カメラ起動」→「撮影する」→「次へ」  
3. 画像認識 or キーワードでカートに追加  
4. **会計** → 注文完了  
5. **売上分析** タブ切替  

## 今後の予定
- 在庫数アラート  
- 複数店舗対応  
- プッシュ通知（Web Push）  
- レスポンシブ改善／ダークモード  

## 制作時間
約 **80時間**

