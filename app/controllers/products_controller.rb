# app/controllers/products_controller.rb
class ProductsController < ApplicationController
  require 'httparty'

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

  # — 新規登録処理 —
  def create
    @product = Product.new(product_params)
    attach_blob_image  # カメラ撮影後の Blob を attach

    if @product.save

      # ここにログ出力を追加
      Rails.logger.info "▶️ register_image_to_flask! name=#{@product.name.inspect}"


      register_image_to_flask!(@product.image, @product.name)
      session.delete(:product_image_blob_id)
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
      # 返り値として S3 側のキーを受け取る
      new_key = register_image_to_flask!(@product.image, @product.name)
      # DB の s3_key カラムにも書き込む
      @product.update!(s3_key: new_key) if new_key.present?

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

    # Flask に画像投げて結果取得
    resp   = HTTParty.post(flask_base_url + "/predict",
               body: { image: File.open(uploaded.tempfile.path) })
    result = JSON.parse(resp.body)

    # ↓ ここを all_scores から all_similarity_scores に合わせる
    raw_scores = result["all_similarity_scores"] || []
    scores     = raw_scores.map { |h| h.transform_keys(&:to_sym) }
    @all_scores = scores

    # 以下は既存の「しきい値以上ヒット or 上位3件取得」ロジックのまま
    hit = @all_scores.select { |c| c[:score] >= 0.2 }
    if hit.any?
      @hit_scores = hit
      @best       = hit.max_by { |c| c[:score] }
      @candidates = hit.first(3)
    else
      @hit_scores = []
      @best       = @all_scores.first
      @candidates = @all_scores.drop(1).first(3)
    end

    # DB レコードを拾っておく（ビューで画像＋名前を使いたい場合）
    @best_product       = Product.find_by(name: @best[:name]) if @best
    @candidate_products = @candidates.map { |c| Product.find_by(name: c[:name]) }.compact

    render :predict_result
  rescue StandardError => e
    Rails.logger.error e.full_message
    render json: { error: "処理エラー" }, status: :internal_server_error
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

  def update_cart
    # （省略：カート更新ロジック）
    redirect_to new_order_products_path
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


  # ActiveStorage Blob → 一時ファイル → Flask に送信
  def register_image_to_flask!(attached_image, name)
    return unless attached_image.attached?

    blob     = attached_image.blob
    filename = nil

    Tempfile.create(['upload', File.extname(blob.filename.to_s)]) do |temp|
      temp.binmode
      temp.write blob.download
      temp.flush

      # S3 にアップするキーを UUID で決定
      filename = "#{SecureRandom.uuid}#{File.extname(blob.filename.to_s)}"

      # → S3 へアップロード
      s3.upload_file(
        Filename: temp.path,
        Bucket: S3_BUCKET,
        Key: filename,
        ExtraArgs: { ContentType: blob.content_type }
      )

      # → Flask にも送信
      resp = HTTParty.post(
        flask_base_url + '/register_image',
        multipart: true,
        body: {
          "name" => name,
          "image" => File.open(temp.path)
        }
      )

      if resp.code == 200
        Rails.logger.info "▶️ register_image_to_flask! sent name=#{name.inspect}"

        # ← ここで DB にも書き込む
        @product.update!(s3_key: filename)
      else
        Rails.logger.error "Flask 画像登録失敗（#{resp.code}）: #{resp.body}"
      end
    end

    filename
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
