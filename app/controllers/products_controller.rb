class ProductsController < ApplicationController
  # CSRFトークンの検証を予測APIでスキップ（fetch対応のため）
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

  # 画像予測API（仮ロジック）
  def predict
    uploaded_file = params[:image]

    # 登録済みの中から「メロンパン」「クロワッサン」だけを抽出
    available_products = Product.where(name: ["メロンパン", "クロワッサン"])

    if available_products.any?
      product = available_products.sample
      render json: { name: product.name }
    else
      render json: { error: "対象商品が登録されていません" }, status: :not_found
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
