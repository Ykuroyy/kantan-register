Rails.application.routes.draw do
  # トップページ
  root "top#index"

  # 商品管理（登録・編集・削除・検索）
  resources :products do
    patch :remove_image, on: :member  # 画像削除用のルート
  end

  # 注文管理（レジ画面、カート追加、注文保存）
  resources :orders, only: [:new, :create] do
    post 'add_to_cart', on: :collection  # カートに追加するルート
  end

  # カメラ画面（撮影ボタンでpredictへ）
  get "/camera", to: "products#camera", as: :camera

  # 撮影画像をサーバーに送信してAI予測
  post "/image_predict", to: "products#predict", as: :image_predict

  # 売上分析ページ（Chart.js対応）
  get "/reports", to: "reports#index", as: :reports

  # ヘルスチェック（Renderや監視サービス用）
  get "up" => "rails/health#show", as: :rails_health_check
end
