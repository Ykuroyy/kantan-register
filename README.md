# Kantan Register

## アプリケーション概要

シンプルな商品登録・在庫管理・レジ機能を備えたWebアプリケーションです。

* **商品登録・編集・削除**：カタカナのみの名前制約、価格のバリデーション
* **画像アップロード**：ActiveStorage＋カメラ撮影連携
* **レジ機能**：画像認識（Flask/SSIM）とキーワード検索でカートに追加
* **カート管理**：セッションベースのカート、数量更新・クリア
* **注文履歴**：Order／OrderItem モデルで履歴保持
* **売上分析ダッシュボード**：年間／月間／日別の売上グラフとサマリー

---

## URL

* デプロイ済み環境: `https://kantan-register.onrender.com`
  （デプロイ後に更新）

---

## テスト用アカウント

* **Basic認証**

  * ユーザー名：`admin`
  * パスワード：`2222`

---

## 利用方法

1. トップページ → 商品登録画面 → 新規商品登録
2. 商品一覧で詳細確認
3. レジ画面で画像認識 or キーワード検索 → カートに追加
4. カート内で数量調整 → 会計実行
5. 注文完了画面で内容確認

---

## 作成背景

* 小規模店舗やイベント出店での簡易POSを想定
* ブラウザだけで手軽に管理・会計を完結させる

---

## 実装機能

1. **商品登録・編集・削除**
2. **画像アップロード & カメラ撮影**
3. **Flask連携の画像認識**
4. **キーワード検索レジ**
5. **セッションカート**
6. **売上分析（年間・月間・日別）**
 

<details>
<summary>各機能のスクリーンショット/GIF（Gyazoリンク）</summary>

* 商品登録画面：`https://gyazo.com/xxx`
* 画像認識レジ：`https://gyazo.com/yyy`
* 売上分析ダッシュボード：`https://gyazo.com/zzz`

</details>

---

## 今後の実装予定

* ユーザー認証・ログイン
* 在庫数アラート
* 複数店舗対応
* ダークモード
* 注文履歴管理

---

## データベース設計

ER図：`kantan-register-er-diagram.png`

---

## 画面遷移図

図：`kantan-register-flow.png`

---

## 開発環境

* Ruby 3.2.0 / Rails 7.1.5
* MySQL 8
* Python Flask (画像認識)
* ActiveStorage

---

## ローカルセットアップ

```bash
# リポジトリをクローン
git clone https://github.com/Ykuroyy/kantan-register.git
cd kantan-register

# 依存インストール
bundle install

# DB準備
rails db:create db:migrate

# Rails サーバ起動
rails server

# 別ターミナルで Flask サーバ起動
cd flask_server && python app.py
```

---

## 工夫ポイント

* ドラッグ&ドロップ不要のシンプルUX
* セッションで軽量カート管理
* Ruby側集計でタイムゾーン問題を吸収

---

## 改善点

* 機械学習モデルの導入（認識精度向上）
* テストコード充実 (RSpec／Capybara)
* Docker 化による環境再現性向上

---

## 制作時間

約 **80時間**
