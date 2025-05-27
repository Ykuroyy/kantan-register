
# Kantan Register

シンプルな商品登録・在庫管理・AI画像認識レジ機能を備えたWebアプリケーションです。

---

## Overview

親しみやすく、誰でもすぐに使えるシンプル POS システム。
Rails のフロントエンドと MySQL／PostgreSQL をバックエンドに、
Flask サーバー（Python）＋SSIM（構造類似度）＋ORB（特徴点マッチング）による比較で、撮影画像と登録画像をマッチングします。


---


## 主な機能

| 機能                     | 説明                                                                 |
|--------------------------|----------------------------------------------------------------------|
| **商品管理**             | カタカナのみの名前制約、価格バリデーション                             |
| **画像アップロード**     | ActiveStorage ＋ カメラ撮影連携                                       |
| **AI画像認識レジ**       | Flask サーバー（Python）＋SSIM／ORB による類似度比較
 |
| **キーワード検索レジ**   | 商品名キーワード検索でカートに追加                                     |
| **カート管理**           | セッションベース、数量更新・クリア                                     |
| **売上分析ダッシュボード** | 年次／月次／日次切替の売上グラフとサマリー指標
 |
| **管理画面リセット機能** |GET /admin/reset_all?token=… で全データ削除（Basic 認証下）            |

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
- Sprockets / Turbo / Stimulus  
- ActiveStorage（画像管理、S3連携）    
- Chart.js（グラフ描画） 

### Python（画像認識）サイド

- Python 3.10 / Flask  
- Pillow, NumPy, scikit‐image, ORB(CV2) 
- gunicorn, Flask‐CORS, requests  


## 画面遷移
- **トップ** → 商品一覧 → 新規登録／編集
- **レジ画面** → カメラ認識 or キーワード → カート追加
- **カート画面** → 数量更新 → 会計
- **注文完了** → 履歴保存
- **売上分析** → 年次／月次／日次切替

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
- Flask で画像認識処理を切り出し、Rails とは疎結合化
- シンプル UI で誰でも扱いやすい

## 使い方
1. **トップページ** → 商品登録  
2. **レジ画面** → 「撮影する」
3. 画像認識 or キーワードでカートに追加  
4. **会計** → 注文完了  
5. **売上分析** タブ切替 （グラフ表示で売上を可視化） 

## 今後の予定
- 在庫数アラート  
- 複数店舗対応  
- Web プッシュ通知
- レスポンシブ改善／ダークモード  

## 制作時間
約 **100時間**

---