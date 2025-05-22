Rails.application.routes.draw do
  # トップページ
  root "top#index"

  # カメラ関連（撮影と認識）
  get  "/camera",              to: "products#camera",           as: :camera
  post "/camera/capture_product", to: "products#capture_product", as: :capture_product_image
  post "/image_predict",       to: "products#predict",          as: :image_predict
  get  "/predict_result",      to: "products#predict_result"

  # 商品管理（登録・編集・削除・検索）
  resources :products do
    collection do
      post 'capture_product'
    end
  end

  
  # 注文・カート・支払い処理
  resources :orders, only: [:create] do
    collection do
      get   :new_order,    to: "products#new_order", as: :new_order
      patch :update_cart,  to: "products#update_cart"
      post  :clear_cart,   to: "products#clear_cart"
      post  :create_order, to: "products#create_order"
      # delete :remove_item ← 必要になった時に追加でOK
    end
  end


  # 売上分析ページ（Chart.js対応など）
  get "/reports", to: "reports#index", as: :reports

  # Render用ヘルスチェック
  get "up", to: "rails/health#show", as: :rails_health_check
end
