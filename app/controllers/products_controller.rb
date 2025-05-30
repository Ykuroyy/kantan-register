class ProductsController < ApplicationController
  require 'httparty'
  require 'aws-sdk-s3'
  require 'securerandom'

  # app/controllers/products_controller.rb
  require 'net/http'

  def build_cache
    uri = URI.parse("https://ai-server-f6si.onrender.com/build_cache")  # 例: https://kantan-register-flask.onrender.com/build_cache
    response = Net::HTTP.post(uri, "", { "Content-Type" => "application/json" })

    if response.is_a?(Net::HTTPSuccess)
      flash[:notice] = "✅ キャッシュ再構築リクエストを送信しました"
    else
      flash[:alert] = "❌ キャッシュ再構築に失敗しました: #{response.body}"
    end

    redirect_to request.referer || root_path
  end





  S3_BUCKET  = ENV.fetch("S3_BUCKET")
  S3_CLIENT  = Aws::S3::Client.new(
    region: ENV["AWS_REGION"],
    access_key_id: ENV["AWS_ACCESS_KEY_ID"],
    secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
  )

  skip_before_action :verify_authenticity_token, only: [:predict, :capture_product]
  before_action :set_product, only: [:show, :edit, :update, :destroy]
  

  
  # — 商品一覧（レジ画面兼用） —
  def index
    @products = Product.with_attached_image
    @products = @products.where("name LIKE ?", "%#{params[:keyword]}%") if params[:keyword].present? && params[:keyword].match?(/\A[ァ-ヶー－]+\z/)
    @products = @products.order(created_at: :desc)
  end

  def show
    @product = Product.find_by(id: params[:id])
    return unless @product.nil?
      redirect_to products_path, alert: "この商品は存在しません"
    
  end


  # — 新規登録フォーム —
  def new
    @product = Product.new
    session.delete(:product_image_blob_id) unless params[:from_camera] == "1"
  end

  def create
    @product = Product.new(product_params)

    # 画像を session から取り出して attach
    if session[:product_image_blob_id].present?
      blob = ActiveStorage::Blob.find_by(id: session[:product_image_blob_id])
      @product.image.attach(blob) if blob
    end

    if @product.save
      session.delete(:product_image_blob_id)

      # s3_key が未設定なら Flask に送信して key を保存
      unless @product.s3_key.present?
        new_key = register_image_to_flask!(@product.image, @product.name)
        @product.update!(s3_key: new_key) if new_key.present?
      end

      redirect_to products_path, notice: "「#{@product.name}」を登録しました"
    else
      render :new, status: :unprocessable_entity
    end
  end




  # — 編集フォーム —
  def edit
    session.delete(:product_image_blob_id) unless params[:from_camera] == "1"
  end

   # — 更新処理 —# app/controllers/products_controller.rb
  def update
    filtered = product_params
    filtered = filtered.except(:image) unless params[:product][:image].present?
    attach_blob_image

    if @product.update(filtered)
      new_key = register_image_to_flask!(@product.image, @product.name)
      # もし register_image_to_flask! 内で更新していないなら外で書き込む
      @product.update!(s3_key: new_key) if new_key.present? && !@product.s3_key.eql?(new_key)
      redirect_to products_path, notice: '商品情報を更新しました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end


 
  # — 削除処理 —
  def destroy
    @product = Product.find_by(id: params[:id])
    if @product.nil?
      redirect_to products_path, alert: "すでに削除済みです"
      return
    end

    name = @product.name
    @product.destroy!
    redirect_to products_path, notice: "#{name} を削除しました"
  rescue ActiveRecord::InvalidForeignKey
    redirect_to products_path, alert: "#{name} は注文履歴があるため削除できません"
  rescue
    redirect_to products_path, alert: '削除中にエラーが発生しました'
  end




    # — カメラ撮影画面 —
  def camera
    if params[:product_id].present?
      @product = Product.find_by(id: params[:product_id])
    else
      @product = Product.last # ← 直近の商品を仮で渡すなど応急対応も可能
    end
  end


  # — 撮影画像の一時保存 →
  def capture_product
    upload = params[:image]
    return head :bad_request unless upload

    blob = ActiveStorage::Blob.create_and_upload!(
      io: upload.tempfile,
      filename: upload.original_filename,
      content_type: upload.content_type
    )
    session[:product_image_blob_id] = blob.id

    # フローに応じて遷移
    case params[:mode]
    when 'new'  then redirect_to new_product_path(from_camera: 1)
    when 'edit' then redirect_to edit_product_path(params[:product_id], from_camera: 1)
    when 'order'then redirect_to camera_products_path(mode: 'order')
    else             redirect_to new_order_products_path(from_camera: 1)
    end
  end


    
  # — 画像認識リクエスト & 結果表示
  def predict
    uploaded = params[:image]
    return head :bad_request unless uploaded

    begin
      # Flask に画像投げて結果取得
      resp = HTTParty.post(
        flask_base_url + "/predict",
        multipart: true,
        body: {
          image: File.open(uploaded.tempfile.path)
        }
      )

      # HTTP ステータスエラーを検知
      unless resp.success?
        Rails.logger.error "❌ Flask API Error: Status #{resp.code}"
        Rails.logger.error "💬 Response Body: #{resp.body}"
        redirect_to camera_products_path(mode: "order"), alert: "画像認識に失敗しました（Flask側エラー）"
        return
      end

      # JSON パース処理
      begin
        result = JSON.parse(resp.body)
      rescue JSON::ParserError => e
        Rails.logger.error "❌ JSON Parse Error: #{e.message}"
        Rails.logger.error "💬 Response Body: #{resp.body}"
        redirect_to camera_products_path(mode: "order"), alert: "画像認識に失敗しました（JSONエラー）"
        return
      end

      # Flask 側で返ってくるキーが "all_similarity_scores"
      raw_scores = result["all_similarity_scores"] || []
      @all_similarity_scores = raw_scores.map { |h| h.transform_keys(&:to_sym) }

      hit = @all_similarity_scores.select { |c| c[:score] >= 0.1 }
      if hit.any?
        @hit_scores = hit
        @best       = hit.max_by { |c| c[:score] }
        @candidates = hit.first(3)
      else
        @hit_scores = []
        @best       = @all_similarity_scores.first
        @candidates = @all_similarity_scores.drop(1).first(3)
      end

      @best_product       = Product.find_by(name: @best[:name]) if @best
      @candidate_products = @candidates.map { |c| Product.find_by(name: c[:name]) }.compact

      render :predict_result
    rescue StandardError => e
      Rails.logger.error e.full_message
      redirect_to camera_products_path(mode: "order"), alert: "画像認識に失敗しました（Railsエラー）"
    end
  end

  # — レジ画面 —
  def new_order
    if params[:recognized_name].present?
      prod = Product.find_by(name: params[:recognized_name])
      if prod
        _add_to_cart(prod.id)
        flash.now[:notice] = "#{prod.name} をカートに追加しました"
      else
        flash.now[:alert]  = "商品が見つかりませんでした"
      end
    end

    @cart_items = cart_items
    @total      = calculate_total_price

    @products = Product.with_attached_image.order(created_at: :desc)
    @products = @products.where("name LIKE ?", "%#{params[:keyword]}%") if params[:keyword].present?
  end

  def add_to_cart
    prod = Product.find_by(name: params[:recognized_name])
    if prod
      _add_to_cart(prod.id)
      redirect_to new_order_products_path, notice: "#{prod.name} をカートに追加しました"
    else
      redirect_to new_order_products_path, alert:  "商品が見つかりませんでした"
    end
  end

  
  # — カート内商品の数量更新 —# app/controllers/products_controller.rb
  def update_cart
    new_q = params[:quantity] || {}
    # session[:cart] は [{ "product_id"=>1, "quantity"=>2 }, …]
    session[:cart].delete_if do |item|
      pid = item["product_id"].to_s
      q   = new_q[pid].to_i
      # ０以下ならカートから完全に削除
      next true if q <= 0
      # それ以外は更新
      item["quantity"] = q
      false
    end

    redirect_to new_order_products_path, notice: "カートを更新しました"
  end

  def clear_cart
    session[:cart] = []
    redirect_to new_order_products_path, notice: "カートを空にしました"
  end

  def create_order
    return redirect_to(new_order_products_path, alert: "カートが空です") if current_cart.empty?

    order = Order.create(total_price: calculate_total_price)
    current_cart.each do |item|
      order.order_items.create(product_id: item["product_id"], quantity: item["quantity"])
    end
    session[:cart] = []
    redirect_to complete_order_path(order), notice: "注文が確定しました（合計: ¥#{order.total_price}）"
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :price, :image)
  end

  # capture_product で保存した Blob を @product に attach
  def attach_blob_image
    if (id = session.delete(:product_image_blob_id)) && (blob = ActiveStorage::Blob.find_by(id: id))
        @product.image.attach(blob)
    end
  end

  # Flask API のベース URL を返す
  def flask_base_url
    if Rails.env.production?
      "https://ai-server-f6si.onrender.com"
    else
      "http://localhost:10000"
    end
  end


  # ActiveStorage Blob → 一時ファイル → S3 と Flask に送信
  # 戻り値として S3 へアップしたキー（filename）を返す
  def register_image_to_flask!(attached_image, name)
    return unless attached_image.attached?

    # URLを取得
    url = Rails.application.routes.url_helpers.rails_blob_url(attached_image, only_path: false)

    # Flaskへ送信
    resp = HTTParty.post(
      "#{flask_base_url}/register_image_v2",
      headers: { "Content-Type" => "application/json" },
      body: {
        name: name,
        image_url: url
      }.to_json
    )

    if resp.code == 200
      Rails.logger.info "✅ register_image_to_flask_v2! success: #{name}"
      parsed = JSON.parse(resp.body)
      parsed["filename"] # ← S3 に保存された key を取得
    else
      Rails.logger.error "❌ Flask 画像URL登録失敗（#{resp.code}）: #{resp.body}"
      nil
    end
  end





  # カート追加ヘルパー
  def _add_to_cart(pid)
    item = current_cart.find { |i| i["product_id"] == pid }
    if item
      item["quantity"] += 1
    else
      current_cart << { "product_id" => pid, "quantity" => 1 }
    end
  end
end
