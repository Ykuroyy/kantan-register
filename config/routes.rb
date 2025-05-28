# ✅ config/routes.rb（リファクタ済み最終版）
Rails.application.routes.draw do
  # トップページ
  root "top#index"

  # 商品関連（カメラ・AI・カート表示＋追加）
  resources :products do
    collection do
      get    :camera            # カメラ起動
      post   :capture_product   # 撮影した画像を保存
      post   :predict           # Flask画像認識
      # get    :predict_result    # 認識結果確認
      get    :new_order         # レジ画面（カート内容表示）
      patch  :update_cart       # カート数量更新
      delete :clear_cart        # カートを空にする
      post   :add_to_cart       # 商品をカートに追加
      post   :create_order      # 会計処理（注文作成）
      post 'products/predict', to: 'products#predict'
    end
  end

  # 注文完了のみ必要なので orders は member のみに
  resources :orders, only: [] do
    member do
      get :complete
    end
  end

  # 売上分析ページ
  get '/orders/analytics', to: 'orders#analytics', as: :orders_analytics



  # Render用ヘルスチェック
  get "up", to: "rails/health#show", as: :rails_health_check
end
