class ProductsController < ApplicationController
  require 'httparty'
  require 'json'

  skip_before_action :verify_authenticity_token, only: [:predict]
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
  end

  def create
    @product = Product.new(product_params)
    if @product.save
      session.delete(:product_image_blob_id)
      send_image_to_flask(@product.image, @product.name)
      redirect_to products_path, notice: "商品を登録しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if params[:remove_image] == "1"
      @product.image.purge if @product.image.attached?
    end

    if @product.update(product_params)
      redirect_to products_path, notice: "商品情報を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    begin
      @product.destroy
      redirect_to products_path, notice: "商品を削除しました"
    rescue ActiveRecord::InvalidForeignKey
      redirect_to products_path, alert: "この商品は注文に使われているため削除できません"
    end
  end

  def camera; end

  def capture_product
    uploaded_io = params[:image]
    blob = ActiveStorage::Blob.create_and_upload!(
      io: uploaded_io.tempfile,
      filename: uploaded_io.original_filename,
      content_type: uploaded_io.content_type
    )
    session[:product_image_blob_id] = blob.id
    redirect_to params[:product_id].present? ? edit_product_path(params[:product_id]) : new_product_path
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
      Rails.logger.info("Flaskからの生レスポンス: #{response.body}")
      raise "Flaskの返答コードが異常: #{response.code}" unless response.code == 200
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
      Rails.logger.error("predictアクションでエラー: #{e.message}")
      @error = "画像認識中にエラーが発生しました"
      render :camera
    end
  end

  def new_order
    @cart = session[:cart] ||= []
    if params[:recognized_name].present?
      product = Product.find_by(name: params[:recognized_name])
      if product
        existing = @cart.find { |item| item["product_id"] == product.id }
        if existing
          existing["quantity"] += 1
        else
          @cart << { "product_id" => product.id, "quantity" => 1 }
        end
        flash[:notice] = "#{product.name} をカートに追加しました"
      else
        flash[:alert] = "商品が見つかりませんでした"
      end
    end
    if params[:keyword].present? && params[:keyword].match?(/\A[ァ-ヶー－]+\z/)
      @products = Product.where("name LIKE ?", "%#{params[:keyword]}%")
    else
      @products = Product.all
    end
    @cart_items = @cart.map do |item|
      product = Product.find_by(id: item["product_id"])
      quantity = item["quantity"]
      subtotal = product && quantity ? product.price.to_i * quantity : 0
      { product: product, quantity: quantity, subtotal: subtotal }
    end
    @total = @cart_items.sum { |item| item[:subtotal] }
  end

  def update_cart
    @cart = session[:cart] ||= []
    params[:quantities].each do |product_id, quantity|
      item = @cart.find { |i| i["product_id"] == product_id.to_i }
      if item
        if quantity.to_i <= 0
          @cart.delete(item)
        else
          item["quantity"] = quantity.to_i
        end
      end
    end
    redirect_to new_order_path
  end

  def clear_cart
    session[:cart] = []
    redirect_to new_order_path, notice: "カートを空にしました"
  end

  def create_order
    @cart = session[:cart] || []
    if @cart.empty?
      redirect_to new_order_path, alert: "カートが空です"
      return
    end

    total_amount = 0
    order_summary = @cart.map do |item|
      product = Product.find_by(id: item["product_id"])
      next unless product
      quantity = item["quantity"]
      subtotal = product.price.to_i * quantity
      total_amount += subtotal
      "#{product.name} x#{quantity} = ¥#{subtotal}"
    end.compact

    Rails.logger.info("注文内容: #{order_summary.join(", ")}, 合計: ¥#{total_amount}")
    session[:cart] = []
    redirect_to new_order_path, notice: "注文を確定しました（合計: ¥#{total_amount}）"
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
    file = image.download
    tempfile = Tempfile.new(["upload", ".png"])
    tempfile.binmode
    tempfile.write(file)
    tempfile.rewind
    begin
      response = HTTParty.post("https://ai-server-f6si.onrender.com/register_image",
        body: { image: File.open(tempfile.path), name: name },
        headers: { 'Content-Type' => 'multipart/form-data' }
      )
      Rails.logger.info("Flaskへの送信結果: #{response.code} #{response.body}")
    rescue => e
      Rails.logger.error("Flaskへの送信失敗: #{e.message}")
    ensure
      tempfile.close
      tempfile.unlink
    end
  end
end
