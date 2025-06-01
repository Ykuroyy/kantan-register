# 🧾 Kantan Register

**高齢者にもやさしい、シンプルで直感的に使えるAI画像認識Webレジアプリケーション。**  
Rails × Python（Flask）で構築し、商品登録・撮影認識・売上分析まで一括管理。

---

## Overview

親しみやすく、誰でもすぐに使えるシンプルPOSシステム。  
Rails (Ruby on Rails) をフロントエンドおよびメインのバックエンドとし、画像認識処理はPythonのFlaskサーバーが担当します。
データベースは開発環境でMySQL、本番環境 (Render.com) ではPostgreSQLを使用しています。
AI画像認識は、**Flaskサーバー（Python）でSSIM／SIFT／ORB** の複数のアルゴリズムによる特徴比較を行い、その複合スコアに基づいて、
撮影画像と登録画像を高精度マッチングします。

---


## 主な機能


| 機能 | 説明 |
|------|------|
| **商品管理** | カタカナのみの名前制約、価格バリデーション |
| **画像アップロード** | ActiveStorage (S3連携)＋カメラ撮影 |
| **AI画像認識レジ** | FlaskでSSIM/SIFT/ORBを用いた商品特定 |
| **キーワード検索レジ** | 商品名キーワード検索でカートに追加 |
| **カート管理** | 商品追加・数量更新・カートクリア |
| **売上分析ダッシュボード** | 年次/月次/日次のグラフとサマリー表示 |
| **管理リセット機能** | `/admin/reset_all?token=...` |
| **Basic認証** | 管理画面に認証を適用 |


---

## Live Demo
Railsアプリケーション: https://kantan-register.onrender.com  
AI画像認識サーバー(Flask): https://ai-server-f6si.onrender.com (Railsアプリから内部的に呼び出されます)

<!-- _Basic 認証_   -->
<!-- - ユーザー名：`admin`   -->
<!-- - パスワード：`2222`   -->

---


## テクノロジー

### Rails サイド

- Ruby 3.2.0 / Rails 7.1.5.1 
- データベース: MySQL 8.0（開発環境）、PostgreSQL（本番環境 on Render.com）
- アセットパイプライン: Sprockets (主に `app/assets` を使用)
- フロントエンド: Turbo Drive, Stimulus.js
- 画像管理: ActiveStorage (Amazon S3 に画像を保存)
- 売上分析: groupdate gem
- グラフ描画: Chart.js

本番環境では、Railsが `url_for(@product.image, host: ...)` を使ってS3上の画像URLを生成し、FlaskサーバーはこのURLから `requests.get(image_url)` を用いて画像データを取得・処理します。

### Python（画像認識）サイド

- Python 3.13.2  
- Flask 3.1.1
- Pillow (PIL Fork)
- NumPy
- scikit-image (SSIM計算用)
- OpenCV (ORB/SIFT特徴量抽出用)
- gunicorn  
- Flask-CORS  
- requests 2.31.0
- SQLAlchemy 2.0.20 / psycopg2-binary 2.9.6（本番でDBマッピングを使う場合）


#### `requirements.txt` 抜粋
<!-- このセクションは、主要なライブラリとそのバージョンを記載するのに役立ちます -->
```text
Flask==3.1.1
Pillow==11.2.1
numpy==2.2.6
scikit-image==0.25.2
opencv-python==4.11.0.86
gunicorn==23.0.0
Flask-CORS==6.0.0
requests==2.32.3
SQLAlchemy==2.0.20
psycopg2-binary==2.9.6
boto3==1.38.23

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
| `s3_key`    | string   | 登録済み画像の S3 キー保存用        |
| `created_at`| datetime |                                 |
| `updated_at`| datetime |                                 |



### orders / order_items テーブル
- `orders`      : 購入トランザクション  
- `order_items` : 商品×数量×価格の中間テーブル  


## データベース構造図（ER図）

![ER図](kantan-register-er-diagram.png)

## 画面遷移図（ビジュアル）

![画面遷移図](kantan-register-flow.png)


## 開発背景
- 小規模店舗やイベント出店での手軽な POS を目指して開発 
- Flask で画像認識処理を切り出し、Rails とは疎結合化
- シンプル UI で誰でも扱いやすい

## 注意事項（ご利用前にお読みください）

- 商品を登録・編集・削除した場合は、**必ず「AIサーバーのキャッシュを再構築」ボタンを押してください**。  
  → これを行わないと、Flask側の認識結果に反映されません。

- 商品を撮影する際は、以下を心がけてください：  
  - **背景は白色**にする（例：白テーブル・白い紙の上など）  
  - 商品が**画面の80％程度を占める大きさ**になるように調整  
  - **ピントをしっかり合わせてから撮影**する  

上記を守ることで、AI画像認識の精度が大きく向上します。


## 使い方
1. **トップページ** → 商品登録  
2. **レジ画面** → 「撮影する」
3. 画像認識 or キーワードでカートに追加  
4. **会計** → 注文完了  
5. **売上分析** タブ切替 （グラフ表示で売上を可視化） 



## 📱 スマホ操作デモ（録画）

実際のレジ操作の様子を動画で確認できます：

- [🆕 新規商品登録 → AIキャッシュ再構築の流れ](https://i.gyazo.com/31e1a58c9cbf006d1d09f5e50cfe6e32.gif)
- [📸 レジ画面①：カメラ撮影 → 商品認識 → 会計完了](https://i.gyazo.com/0faad65d0ece249a0482196c472e7b0a.gif)
- [🛒 レジ画面②：カメラ撮影 → カート編集 → 会計完了](https://i.gyazo.com/78706e029cdd0edc752c25403b908f11.gif)



## 今後の予定
- 在庫数アラート  
- 複数店舗対応  
- Web プッシュ通知
- レスポンシブ改善／ダークモード  

## 制作時間
約 **140時間**

---