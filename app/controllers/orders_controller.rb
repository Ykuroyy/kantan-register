class OrdersController < ApplicationController
  before_action :initialize_cart, only: [:new, :add_to_cart, :create]

  def new
    @products = Product.all

    # 1. カート初期化（念のため）
    session[:cart] ||= []

    # 2. カメラで認識された商品名がある場合、自動追加
    if params[:recognized].present?
      recognized_name = params[:recognized]
      product = Product.find_by(name: recognized_name)

      if product
        unless session[:cart].include?(product.id)
          session[:cart] << product.id
          flash.now[:notice] = "#{recognized_name} をカートに追加しました"
        end
      else
        flash.now[:alert] = "#{recognized_name} は商品として登録されていません"
      end
    end

    # 3. カートに入っている商品を取得（←これが画面に表示される）
    @cart_items = Product.where(id: session[:cart])
  end

  def add_to_cart
    product_id = params[:product_id].to_i
    session[:cart] << product_id unless session[:cart].include?(product_id)
    redirect_to new_order_path, notice: "商品をカートに追加しました"
  end

  def create
    if session[:cart].blank?
      redirect_to new_order_path, alert: "カートが空です"
      return
    end

    order = Order.create!
    session[:cart].each do |product_id|
      OrderItem.create!(order: order, product_id: product_id)
    end

    session[:cart] = []
    redirect_to root_path, notice: "注文を保存しました！"
  end

  private

  def initialize_cart
    session[:cart] ||= []
  end
end
