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
    attach_blob_image

    if @product.save
      session.delete(:product_image_blob_id)
      send_image_to_flask(@product.image, @product.name)
      redirect_to products_path, notice: '登録完了'
    else
      render :new
    end
  end


  def edit
    session.delete(:product_image_blob_id) unless params[:from_camera] == "1"
  end

  def update
    attach_blob_image
    update_params = product_params
    update_params = update_params.except(:image) unless params[:product][:image].present?

     if @product.update(update_params)
      send_image_to_flask(@product.image, @product.name)
      redirect_to products_path, notice: '商品情報を更新しました。'
     else
      render :edit, status: :unprocessable_entity
     end
  end



  def destroy
    name = @product.name
    @product.destroy!
    redirect_to products_path, notice: "#{name} を削除しました"
  rescue ActiveRecord::InvalidForeignKey
    redirect_to products_path, alert: "#{name} は注文履歴があるため削除できません"
  rescue => e
    logger.error "削除エラー: #{e.message}"
    redirect_to products_path, alert: '削除中にエラーが発生しました'
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
    mode = params[:mode]
    product_id = params[:product_id]
    # 遷移先をmodeで選択
    case mode
    when 'edit'
      redirect_to edit_product_path(product_id, from_camera: 1)
    when 'new'
      redirect_to new_product_path(from_camera: 1)
    when 'order'
      redirect_to camera_products_path(mode: 'order')
    else
      redirect_to new_order_products_path(from_camera: 1)
    end
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
    rescue
      @error = "画像認識中にエラーが発生しました"
      render :camera
    end
  end

  def predict_result
    @predicted_name = params[:predicted_name]
    @score = params[:score]&.to_f || 0.0
    @product = Product.find_by(name: @predicted_name)
  end


  # レジ画面
  def new_order
    # — AI で認識されたらカートに追加 —
    if params[:recognized_name].present?
      product = Product.find_by(name: params[:recognized_name])
      if product
        _add_to_cart(product.id)
        flash.now[:notice] = "#{product.name} をカートに追加しました"
      else
        flash.now[:alert] = "商品が見つかりませんでした"
      end
    end

    # — カート内容 —
    @cart_items = cart_items
    @total      = calculate_total_price
  
  
    # — 検索結果 or 全商品を @products にセット —
    base_products = Product.all.order(created_at: :desc)
    if params[:keyword].present?
      @products = base_products.where("name LIKE ?", "%#{params[:keyword]}%")
    else
      @products = base_products
    end
  end

 # 検索結果／AI 認識結果からの追加共通
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

    puts "✅ Flaskへ送信準備: #{image_url}"
   
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
#
