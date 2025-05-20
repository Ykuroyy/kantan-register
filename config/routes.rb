Rails.application.routes.draw do

  # トップページ
  root "top#index"

  # 商品登録用：撮影画像を保存して new に渡す
  post "/camera/capture_product", to: "products#capture_product", as: :capture_product_image
    # カメラ画面（撮影ボタンでpredictへ）
  get "/camera", to: "products#camera", as: :camera


  # 商品管理（登録・編集・削除・検索）
  resources :products do
    patch :remove_image, on: :member  # 画像削除用のルート
  end

  # 注文管理（レジ画面、カート追加、注文保存）
  resources :orders, only: [:new, :create] do
    collection do
      post :add_to_cart
      patch :update_cart
      post :clear_cart
      delete :remove_item  # 商品個別削除に必要
    end
  end



  # 撮影画像をサーバーに送信してAI予測
  post "/image_predict", to: "products#predict", as: :image_predict





  # 売上分析ページ（Chart.js対応）
  get "/reports", to: "reports#index", as: :reports

  # ヘルスチェック（Renderや監視サービス用）
  get "up" => "rails/health#show", as: :rails_health_check
end
