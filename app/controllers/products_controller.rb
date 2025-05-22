# ✅ app/controllers/products_controller.rb（レジ機能含む最終版）
class ProductsController < ApplicationController
  require 'httparty'
  require 'json'

  skip_before_action :verify_authenticity_token, only: [:predict, :capture_product]
  before_action :set_product, only: [:show, :edit, :update, :destroy]

  def index
    if params[:keyword].present? && params[:keyword].match?(/\A[ァ-ヶー－]+\z/)
      @products = Product.where("name LIKE ?", "%#{params[:keyword]}%").order(created_at: :desc)
    else
      @products = Product.all.order(created_at: :desc)
    end
  end

  def show; end

  def new
    @product = Product.new
    session.delete(:product_image_blob_id) unless params[:from_camera] == "1"
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      send_image_to_flask(@product.image, @product.name)
      redirect_to products_path, notice: "登録完了"
    else
      render :new
    end
  end

  def edit
    session.delete(:product_image_blob_id) unless params[:from_camera] == "1"
  end

  def update
    if session[:product_image_blob_id].present?
      blob = ActiveStorage::Blob.find_by(id: session[:product_image_blob_id])
      if blob
        @product.image.purge if @product.image.attached?
        @product.image.attach(blob)
      end
      session.delete(:product_image_blob_id)
    end

    update_params = product_params
    update_params = update_params.except(:image) unless params[:product][:image].present?

    if @product.update(update_params)
      send_image_to_flask(@product.image, @product.name)
      redirect_to products_path, notice: "商品情報を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @product.destroy
      redirect_to products_path, notice: "商品を削除しました"
    else
      redirect_to products_path, alert: "この商品は削除できません"
    end
  end

  def camera; end

  def capture_product
    uploaded_io = params[:image]
    return head :bad_request unless uploaded_io

    blob = ActiveStorage::Blob.create_and_upload!(
      io: uploaded_io.tempfile,
      filename: uploaded_io.original_filename,
      content_type: uploaded_io.content_type
    )

    session[:product_image_blob_id] = blob.id
    redirect_to params[:product_id].present? ? edit_product_path(params[:product_id], from_camera: 1) : new_order_products_path(from_camera: 1)
  end

  def predict
    image_file = params[:image]
    return render json: { error: "画像がありません" }, status: :bad_request if image_file.blank?

    tempfile = image_file.tempfile
    begin
      response = HTTParty.post("https://ai-server-f6si.onrender.com/predict",
        body: { image: File.open(tempfile.path) },
        headers: { 'Content-Type' => 'multipart/form-data' }
      )
      result = JSON.parse(response.body)

      if result["name"]
        @predicted_name = result["name"]
        @score = result["score"]
        @product = Product.find_by(name: @predicted_name)
        render :predict_result
      else
        @error = "商品を認識できませんでした"
        render :camera
      end
    rescue => e
      @error = "画像認識中にエラーが発生しました"
      render :camera
    end
  end

  def predict_result
    @predicted_name = params[:predicted_name]
    @score = params[:score]&.to_f || 0.0
    @product = Product.find_by(name: @predicted_name)
  end

  def new_order
    if params[:recognized_name].present?
      product = Product.find_by(name: params[:recognized_name])
      if product
        _add_to_cart(product.id)
        flash.now[:notice] = "#{product.name} をカートに追加しました"
      else
        flash.now[:alert] = "商品が見つかりませんでした"
      end
    end

    @cart_items = cart_items
    @total = calculate_total_price
    @products = Product.all.order(created_at: :desc)
  end

  def add_to_cart
    product = Product.find_by(name: params[:recognized_name])
    if product
      _add_to_cart(product.id)
      redirect_to new_order_products_path, notice: "#{product.name} をカートに追加しました"
    else
      redirect_to new_order_products_path, alert: "商品が見つかりませんでした"
    end
  end

  def update_cart
    current_cart.select! { |item| item.is_a?(Hash) && item.key?("product_id") && item.key?("quantity") }

    params[:quantities].each do |product_id, quantity|
      item = current_cart.find { |i| i["product_id"] == product_id.to_i }
      if item
        if quantity.to_i <= 0
          current_cart.delete(item)
        else
          item["quantity"] = quantity.to_i
        end
      end
    end
    redirect_to new_order_products_path
  end

  def clear_cart
    session[:cart] = []
    redirect_to new_order_products_path, notice: "カートを空にしました"
  end

  def create_order
    return redirect_to new_order_products_path, alert: "カートが空です" if current_cart.empty?

    total_price = calculate_total_price
    order = Order.new(total_price: total_price)

    if order.save
      cart_items.each do |item|
        order.order_items.create(product: item[:product], quantity: item[:quantity])
      end
      session[:cart] = []
      redirect_to complete_order_path(order), notice: "注文が確定しました（合計: ¥#{total_price}）"
    else
      redirect_to new_order_products_path, alert: "注文処理に失敗しました"
    end
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :price, :image)
  end

  def send_image_to_flask(image, name)
    return unless image.attached?

    host = Rails.env.production? ? "https://kantan-register.onrender.com" : "http://localhost:3000"
    image_url = Rails.application.routes.url_helpers.rails_blob_url(image, host: host)
    flask_url = Rails.env.production? ? "https://ai-server-f6si.onrender.com" : "http://localhost:10000"

    HTTParty.post("#{flask_url}/register_image", body: {
                    name: name,
                    image_url: image_url
                  })
  end

  def _add_to_cart(product_id)
    product = Product.find_by(id: product_id)
    return unless product

    existing = current_cart.find { |item| item["product_id"] == product.id }
    if existing
      existing["quantity"] += 1
    else
      current_cart << { "product_id" => product.id, "quantity" => 1 }
    end
  end
end
