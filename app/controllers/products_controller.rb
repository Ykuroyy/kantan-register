class ProductsController < ApplicationController
  require 'httparty'
  # require 'aws-sdk-s3' # Active Storage を通じてS3を利用しているため、コントローラでの直接参照は不要な場合があります
  # require 'securerandom' # UUID生成などで必要でなければ不要
  # require 'net/http' # HTTParty を使用しているため、Net::HTTPの直接利用は build_cache 以外では不要かもしれません

  # S3_BUCKET と S3_CLIENT は、このコントローラ内で直接S3バケット操作をしない場合（例: ActiveStorage経由のみの場合）は不要かもしれません。
  # 必要に応じてコメントアウトまたは削除を検討してください。
  # S3_BUCKET = ENV.fetch("S3_BUCKET")
  # S3_CLIENT = Aws::S3::Client.new(
  #   region: ENV["AWS_REGION"],
  #   access_key_id: ENV["AWS_ACCESS_KEY_ID"],
  #   secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
  # )

  skip_before_action :verify_authenticity_token, only: [:predict, :capture_product]
  before_action :set_product, only: [:show, :edit, :update, :destroy]

  def build_cache
    uri = URI.parse("#{flask_base_url}/build_cache")
    response = Net::HTTP.post(uri, "", { "Content-Type" => "application/json" })

    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body) # Flaskからのレスポンスボディをパース
      flash[:notice] = "✅ キャッシュ再構築リクエスト成功: #{result.fetch('message', '完了しました')}" # メッセージを取得して表示
    else
      flash[:alert] = "❌ キャッシュ再構築に失敗しました: #{response.body}"
    end

    redirect_to request.referer || root_path
  end

  def index
    @products = Product.with_attached_image.order(created_at: :desc)
    @products = @products.where("name LIKE ?", "%#{params[:keyword]}%") if params[:keyword].present? && params[:keyword].match?(/\A[ァ-ヶー－]+\z/)
  end

  def show
    @product = Product.find_by(id: params[:id])
    redirect_to products_path, alert: "この商品は存在しません" if @product.nil?
  end

  def new
    @product = Product.new
    session.delete(:product_image_blob_id) unless params[:from_camera] == "1"
  end

  def create
    @product = Product.new(product_params)
    if session[:product_image_blob_id].present?
      blob = ActiveStorage::Blob.find_by(id: session[:product_image_blob_id])
      @product.image.attach(blob) if blob
    end

    if @product.save
      session.delete(:product_image_blob_id)
      unless @product.s3_key.present?
        new_key = register_image_to_flask!(@product.image, @product.name)
        if new_key.present?
          @product.update!(s3_key: new_key)
          Rails.logger.info "s3_key updated for Product ID: #{@product.id} to #{new_key}"
        end
      end
      redirect_to products_path, notice: "「#{@product.name}」を登録しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    session.delete(:product_image_blob_id) unless params[:from_camera] == "1"
  end

  def update
    filtered = product_params
    filtered = filtered.except(:image) unless params[:product][:image].present?
    attach_blob_image

    if @product.update(filtered)
      new_key = register_image_to_flask!(@product.image, @product.name)
      if new_key.present? && @product.s3_key != new_key # s3_keyが変更された場合のみ更新
        @product.update!(s3_key: new_key)
        Rails.logger.info "s3_key updated for Product ID: #{@product.id} to #{new_key}"
      end
      redirect_to products_path, notice: '商品情報を更新しました。'
    else
      render :edit, status: :unprocessable_entity
    end
  end

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

  def camera
    @product = params[:product_id].present? ? Product.find_by(id: params[:product_id]) : Product.last
  end

  def capture_product
    upload = params[:image]
      Rails.logger.info "--- ProductsController#capture_product called ---"
      Rails.logger.info "Params: #{params.inspect}"
    return head :bad_request unless upload

    blob = ActiveStorage::Blob.create_and_upload!(
      io: upload.tempfile,
      filename: upload.original_filename,
      content_type: upload.content_type
    )
    session[:product_image_blob_id] = blob.id
      Rails.logger.info "Blob created (ID: #{blob.id}) and stored in session."

    case params[:mode]
    when 'new'  then redirect_to new_product_path(from_camera: 1)
    when 'edit' then redirect_to edit_product_path(params[:product_id], from_camera: 1)
    when 'order'then redirect_to camera_products_path(mode: 'order')
    else             redirect_to new_order_products_path(from_camera: 1)
    end
  end

  def predict
    uploaded = params[:image]
    return head :bad_request unless uploaded

    # Faraday を使う場合はここで初期化
    # conn = Faraday.new(url: flask_base_url) do |faraday|
    #   faraday.request :multipart
    #   faraday.adapter Faraday.default_adapter
    #   faraday.options.timeout = 60
    #   faraday.options.open_timeout = 10
    # end

    begin
      # HTTParty を使用した既存のコード
      resp = HTTParty.post(
        flask_base_url + "/predict",
        multipart: true,
        body: { image: File.open(uploaded.tempfile.path) },
        timeout: 60 # HTTPartyのタイムアウト設定例
      )

      unless resp.success?
        Rails.logger.error "❌ Flask API Error: Status #{resp.code}"
        Rails.logger.error "💬 Response Body: #{resp.body}"
        # camera_products_path は routes.rb で定義された適切なパスに置き換えてください
        redirect_to camera_products_path(mode: "order"), alert: "画像認識サーバーとの通信に失敗しました (ステータス: #{resp.code})。"
        return
      end

      result = JSON.parse(resp.body)
      raw_scores = result["all_similarity_scores"] || []
      @recognition_results = []

      if raw_scores.is_a?(Array)
        raw_scores.each do |item|
          product = Product.find_by(name: item["name"]) # Flaskからのレスポンスは文字列キーの想定
          if product
            @recognition_results << {
              product: product,
              score: item["score"].to_f
            }
          else
            Rails.logger.warn "Product not found in Rails DB for name: #{item['name']}"
          end
        end
        @recognition_results.sort_by! { |r| -r[:score] } # スコアの高い順にソート
      else
        Rails.logger.error "Flask response 'all_similarity_scores' is not an array: #{raw_scores.inspect}"
        flash.now[:alert] = "画像認識サーバーからの応答形式が不正です (スコアリスト)。"
      end

      render :predict_result
    rescue StandardError => e
      Rails.logger.error e.full_message
      redirect_to camera_products_path(mode: "order"), alert: "画像認識に失敗しました（Railsエラー）"
    end
  end
  # ここに recognize_products_from_image メソッドを定義する必要はありません。
  # 既存の predict アクションを上記のように修正することで対応します。


  def new_order
    if params[:recognized_name].present?
      prod = Product.find_by(name: params[:recognized_name])
      if prod
        _add_to_cart(prod.id)
        flash.now[:notice] = "#{prod.name} をカートに追加しました"
      else
        flash.now[:alert] = "商品が見つかりませんでした"
      end
    end

    @cart_items = cart_items
    @total = calculate_total_price
    @products = Product.with_attached_image.order(created_at: :desc)
    @products = @products.where("name LIKE ?", "%#{params[:keyword]}%") if params[:keyword].present?
  end

  def add_to_cart
    prod = Product.find_by(name: params[:recognized_name])
    if prod
      _add_to_cart(prod.id)
      redirect_to new_order_products_path, notice: "#{prod.name} をカートに追加しました"
    else
      redirect_to new_order_products_path, alert: "商品が見つかりませんでした"
    end
  end

  def update_cart
    new_q = params[:quantity] || {}
    session[:cart].delete_if do |item|
      pid = item["product_id"].to_s
      q = new_q[pid].to_i
      next true if q <= 0
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

  def attach_blob_image
    if (id = session.delete(:product_image_blob_id)) && (blob = ActiveStorage::Blob.find_by(id: id))
      @product.image.attach(blob)
    end
  end

  def flask_base_url
    if Rails.env.production?
      "https://ai-server-f6si.onrender.com"
    else
      "http://localhost:10000"
    end
  end

  def register_image_to_flask!(attached_image, name)
    return unless attached_image.attached?
    url = Rails.application.routes.url_helpers.rails_blob_url(attached_image, only_path: false)
    resp = HTTParty.post(
      "#{flask_base_url}/register_image_v2",
      headers: { "Content-Type" => "application/json" },
      body: { name: name, image_url: url }.to_json
    )

    if resp.code == 200
      begin
        parsed = JSON.parse(resp.body)
        s3_key = parsed["s3_key"]
        if s3_key.present?
          Rails.logger.info "✅ register_image_to_flask_v2! success: #{name}, s3_key: #{s3_key}"
          s3_key
        else
          Rails.logger.error "❌ Flask API response missing s3_key. Response: #{resp.body}"
          nil
        end
      rescue JSON::ParserError => e
        Rails.logger.error "❌ Failed to parse JSON response from Flask API: #{e.message}. Response: #{resp.body}"
        nil
      end
    else
      Rails.logger.error "❌ Flask 画像URL登録失敗（#{resp.code}）: #{resp.body}"
      nil
    end
  end

  def _add_to_cart(pid)
    item = current_cart.find { |i| i["product_id"] == pid }
    if item
      item["quantity"] += 1
    else
      current_cart << { "product_id" => pid, "quantity" => 1 }
    end
  end
end
