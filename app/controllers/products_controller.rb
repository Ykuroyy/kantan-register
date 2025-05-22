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

    # 撮影画面から戻ってきたときだけセッション画像を保持
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
    # 撮影画面から戻ってきたときだけセッション画像を保持
    session.delete(:product_image_blob_id) unless params[:from_camera] == "1"
  end



  def update
    # 新しい画像がセッションにあれば、既存の画像を削除してからアタッチ
    if session[:product_image_blob_id].present?
      blob = ActiveStorage::Blob.find_by(id: session[:product_image_blob_id])
      if blob
        @product.image.purge if @product.image.attached?  # ⭐️←これを忘れると前の画像が残る！
        @product.image.attach(blob)
      end
      session.delete(:product_image_blob_id)
    end

    # imageを除いて更新（paramsのimageがnilなら上書きされるのを防ぐ）
    update_params = product_params
    update_params = update_params.except(:image) unless params[:product][:image].present?

    if @product.update(update_params)
     # ✅ 更新成功時のみ Flask に画像を送信（redirect前）
      send_image_to_flask(@product.image, @product.name)
    
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
    return head :bad_request unless uploaded_io

    blob = ActiveStorage::Blob.create_and_upload!(
      io: uploaded_io.tempfile,
      filename: uploaded_io.original_filename,
      content_type: uploaded_io.content_type
    )

    session[:product_image_blob_id] = blob.id

    # ✅ 消さないで！
    # redirect_to params[:product_id].present? ? edit_product_path(params[:product_id]) : new_product_path
    redirect_to params[:product_id].present? ? edit_product_path(params[:product_id], from_camera: 1) : new_order_orders_path(from_camera: 1)

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
  @cart = session[:cart].is_a?(Array) ? session[:cart] : []

  # 商品名で追加処理（AIや検索から）
  if params[:recognized_name].present?
    product = Product.find_by(name: params[:recognized_name])
    if product
      existing = @cart.find { |item| item["product_id"] == product.id }
      if existing
        existing["quantity"] += 1
      else
        @cart << { "product_id" => product.id, "quantity" => 1 }
      end
      session[:cart] = @cart
      flash.now[:notice] = "#{product.name} をカートに追加しました"
    else
      flash.now[:alert] = "商品が見つかりませんでした"
    end
  end

  # カート内容の再計算
  @cart_items = @cart.map do |item|
    next unless item.is_a?(Hash)
    product = Product.find_by(id: item["product_id"])
    quantity = item["quantity"].to_i
    subtotal = product ? product.price.to_i * quantity : 0
    { product: product, quantity: quantity, subtotal: subtotal }
  end.compact

  @total = @cart_items.sum { |item| item[:subtotal] }
  @products = Product.all.order(created_at: :desc)
end



  def update_cart
    @cart = session[:cart] ||= []
    @cart.select! { |item| item.is_a?(Hash) && item.key?("product_id") && item.key?("quantity") }

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
    redirect_to new_order_orders_path
  end

  def clear_cart
    session[:cart] = []
    redirect_to new_order_orders_path, notice: "カートを空にしました"
  end

  def create_order
    @cart = session[:cart] || []
    if @cart.empty?
      redirect_to new_order_orders_path, alert: "カートが空です"
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
    redirect_to new_order_orders_path, notice: "注文を確定しました（合計: ¥#{total_amount}）"
  end


  def predict_result
    @predicted_name = params[:predicted_name]
    @score = params[:score]&.to_f || 0.0
    @product = Product.find_by(name: @predicted_name)
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

    # ✅ 本番／開発でホストを自動切り替え
    host = Rails.env.production? ? "https://kantan-register.onrender.com" : "http://localhost:3000"

    # ✅ 画像URLを取得
    image_url = Rails.application.routes.url_helpers.rails_blob_url(image, host: host)

    flask_url = Rails.env.production? ? "https://ai-server-f6si.onrender.com" : "http://localhost:10000"

    # ✅ Flaskへ送信
    begin
      response = HTTParty.post("#{flask_url}/register_image", body: {
                                 name: name,
                                 image_url: image_url
                               })
                               
      Rails.logger.info("Flaskへ画像URL送信成功: #{response.code} #{response.body}")
    rescue => e
      Rails.logger.error("Flaskへの送信失敗: #{e.message}")
    end
  end
end
