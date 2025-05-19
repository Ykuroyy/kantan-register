class OrdersController < ApplicationController
  before_action :initialize_cart, only: [:new, :add_to_cart, :create, :clear_cart]

  # レジ画面
  def new
    @products = if params[:keyword].present? && params[:keyword].match?(/\A[ァ-ヶー－]+\z/)
                  Product.where("name LIKE ?", "%#{params[:keyword]}%").order(created_at: :desc)
                else
                  Product.all.order(created_at: :desc)
                end

    if params[:recognized].present?
      product = Product.find_by(name: params[:recognized])
      if product
        session[:cart][product.id.to_s] ||= 0
        session[:cart][product.id.to_s] += 1
        flash.now[:notice] = "#{product.name} をカートに追加しました"
      else
        flash.now[:alert] = "商品が見つかりませんでした"
      end
    end

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
      session[:cart][product_id] = quantity.to_i if quantity.to_i > 0
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

  private

  def initialize_cart
    session[:cart] ||= {}
  end
end
