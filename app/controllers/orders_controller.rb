class OrdersController < ApplicationController
  before_action :initialize_cart, only: [:new, :add_to_cart, :create]

  def new
    @products = if params[:keyword].present? && params[:keyword].match?(/\A[ァ-ヶー－]+\z/)
                  Product.where("name LIKE ?", "%#{params[:keyword]}%")
                else
                  Product.all
                end

    # カート
    @cart_items = Product.find(session[:cart]) rescue []

    # カメラ認識商品の自動追加
    if params[:recognized]
      product = Product.find_by(name: params[:recognized])
      if product && !session[:cart].include?(product.id)
        session[:cart] << product.id
        @cart_items = Product.find(session[:cart])
        flash.now[:notice] = "#{product.name} をカートに追加しました"
      end
    end
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
