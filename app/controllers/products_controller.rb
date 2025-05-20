class ProductsController < ApplicationController
  require 'httparty'
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
      session.delete(:product_image_blob_id)

      # ここでFlaskに画像を送信（商品名付き）
      send_image_to_flask(@product.image, @product.name)

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
    begin
      @product.destroy
      redirect_to products_path, notice: "商品を削除しました"
    rescue ActiveRecord::InvalidForeignKey
      redirect_to products_path, alert: "この商品は注文に使われているため削除できません"
    end
  end

  # カメラ起動ページ
  def camera
  end

  # 📸 カメラで撮影した画像を一時保存して商品登録画面へ
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




    # 🔁 Flask API へ画像送信して推定された商品名を受け取る
  def predict
    image_file = params[:image]
    return render json: { error: "画像がありません" }, status: :bad_request if image_file.blank?

    tempfile = image_file.tempfile



    begin
      response = HTTParty.post(
        "http://127.0.0.1:5000/predict",
        body: {
          image: File.open(tempfile.path)
        },
        headers: { 'Content-Type' => 'multipart/form-data' }
      )




      Rails.logger.info("Flaskからの生レスポンス: #{response.body}")



      if response.code != 200
        raise "Flaskの返答コードが異常: #{response.code}"
      end

      result = JSON.parse(response.body)

     if result["name"]
        @predicted_name = result["name"]
        @score = result["score"]
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



    private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :price, :image)
  end

    # Flaskに画像と名前を送信（/register_image）
  def send_image_to_flask(image, name)
    return unless image.attached?

    file = image.download
    tempfile = Tempfile.new(["upload", ".png"])
    tempfile.binmode
    tempfile.write(file)
    tempfile.rewind
    
    begin
      response = HTTParty.post(
        "http://127.0.0.1:5000/register_image",
        body: {
          image: File.open(tempfile.path),
          name: name
        },
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