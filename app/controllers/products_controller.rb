class ProductsController < ApplicationController
  require 'faraday'
  require 'json'

  # fetch対応のため、CSRFトークンの検証をスキップ
  skip_before_action :verify_authenticity_token, only: [:predict]
  before_action :set_product, only: [:show, :edit, :update, :destroy]

  # 商品一覧（カタカナ検索対応）
  def index
    if params[:keyword].present? && params[:keyword].match?(/\A[ァ-ヶー－]+\z/)
      @products = Product.where("name LIKE ?", "%#{params[:keyword]}%").order(created_at: :desc)
    else
      @products = Product.all.order(created_at: :desc)
    end
  end

  # 詳細表示
  def show
  end

  # 商品新規登録フォーム
  def new
    @product = Product.new
  end

  # 商品登録処理
  def create
    @product = Product.new(product_params)
    if @product.save
      session.delete(:product_image_blob_id)  # ← ★ コレが重要
      redirect_to products_path, notice: "商品を登録しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end


  # 編集フォーム
  def edit
  end

  # 商品更新処理（画像削除オプション付き）
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

  # 商品削除
  def destroy
    @product.destroy
    redirect_to products_path, notice: "商品を削除しました。"
  end

  # カメラ起動ページ
  def camera
  end

  # 🔁 Flask API へ画像送信して推定された商品名を受け取る
  def predict
    image_file = params[:image]
    if image_file.blank?
      return render json: { error: "画像がありません" }, status: :bad_request
    end

    begin
      conn = Faraday.new(url: "http://localhost:5000") # Flask API のURL
      response = conn.post("/predict", image: image_file)
      result = JSON.parse(response.body)

      if result["name"]
        render json: { name: result["name"] }
      else
        render json: { error: "商品名が見つかりませんでした" }, status: :not_found
      end
    rescue => e
      render json: { error: "AIサーバーとの通信に失敗しました: #{e.message}" }, status: :internal_server_error
    end
  end

  
  # 📸 カメラで撮影した画像を一時保存して商品登録画面へ（登録用）
  def capture_product
    uploaded_io = params[:image]

    blob = ActiveStorage::Blob.create_and_upload!(
      io: uploaded_io.tempfile,
      filename: uploaded_io.original_filename,
      content_type: uploaded_io.content_type
    )

    session[:product_image_blob_id] = blob.id

    if params[:product_id].present?
      redirect_to edit_product_path(params[:product_id])  # ✅ 編集画面に戻す
    else
      redirect_to new_product_path                        # 新規登録画面に戻す
    end
  end




  private

  # 商品をIDから取得
  def set_product
    @product = Product.find(params[:id])
  end

  # パラメータ許可
  def product_params
    params.require(:product).permit(:name, :price, :image)
  end

  # 画像削除アクション（使っている場合）
  def remove_image
    @product = Product.find(params[:id])
    @product.image.purge
    redirect_to edit_product_path(@product), notice: "画像を削除しました"
  end

end
