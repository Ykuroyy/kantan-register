class OrdersController < ApplicationController
  before_action :initialize_cart, only: [:new, :add_to_cart, :create, :clear_cart]

  # レジ画面
  def new
    # 商品検索（カタカナ）
    @products = if params[:keyword].present? && params[:keyword].match?(/\A[ァ-ヶー－]+\z/)
                  Product.where("name LIKE ?", "%#{params[:keyword]}%").order(created_at: :desc)
                else
                  Product.all.order(created_at: :desc)
                end

    # 🔍 AI画像認識でヒットした商品があればカートに追加
    if params[:recognized_name].present?
      @recognized_name = params[:recognized_name]
      product = Product.find_by(name: @recognized_name)

      if product
        add_product_to_cart(product.id)
        flash.now[:notice] = "#{product.name} をカートに追加しました"
      else
        @similar_products = Product.where("name LIKE ?", "%#{@recognized_name}%")
        flash.now[:alert] = "認識された商品「#{@recognized_name}」は登録されていません"
      end
    end

    # 🛒 カート表示
    @cart_items = session[:cart].map do |product_id, quantity|
      product = Product.find_by(id: product_id)
      { product: product, quantity: quantity } if product
    end.compact
  end






  # カートに追加
  def add_to_cart
    product_id = params[:product_id].to_s
    quantity = params[:quantity].to_i
    quantity = 1 if quantity <= 0

    session[:cart][product_id] ||= 0
    session[:cart][product_id] += quantity

    redirect_to new_order_path, notice: "商品をカートに追加しました"
  end

  # カートを空にする
  def clear_cart
    session[:cart] = {}
    redirect_to new_order_path, notice: "カートをリセットしました"
  end

  # カートの数量を更新
  def update_cart
    updated = params[:quantities] || {}
    updated.each do |product_id, quantity|
      if quantity.to_i > 0
        session[:cart][product_id] = quantity.to_i
      else
        session[:cart].delete(product_id)
      end
    end
    redirect_to new_order_path, notice: "数量を更新しました"
  end

  # 注文作成
  def create
    if session[:cart].blank?
      redirect_to new_order_path, alert: "カートが空です"
      return
    end

    total_price = session[:cart].sum do |product_id, quantity|
      product = Product.find_by(id: product_id)
      product ? product.price * quantity : 0
    end

    order = Order.create!(total_price: total_price)

    session[:cart].each do |product_id, quantity|
      OrderItem.create!(order: order, product_id: product_id, quantity: quantity)
    end

    session[:cart] = {}
    redirect_to root_path, notice: "注文を保存しました！"
  end

  # 商品個別削除
  def remove_item
    product_id = params[:product_id].to_s
    session[:cart].delete(product_id)

    redirect_to new_order_path, notice: "商品をカートから削除しました"
  end

  private

  # カート初期化
  def initialize_cart
    session[:cart] ||= {}
  end

  # 🔁 カートに商品追加（AI認識・通常操作共通）
  def add_product_to_cart(product_id)
    product_id = product_id.to_s
    session[:cart][product_id] ||= 0
    session[:cart][product_id] += 1
  end
end
