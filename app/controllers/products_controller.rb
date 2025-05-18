class ProductsController < ApplicationController
  before_action :set_product, only: [:show, :edit, :update, :destroy]

  # 一覧表示
  def index
    @products = Product.all.order(created_at: :desc)
    if params[:keyword].present? && params[:keyword].match?(/\A[ァ-ヶー－]+\z/)
      @products = Product.where("name LIKE ?", "%#{params[:keyword]}%")
    else
      @products = Product.all
    end
  end

  # 詳細表示
  def show
  end

  # 新規登録フォーム
  def new
    @product = Product.new
  end

  # 登録処理
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

  # 更新処理（画像変更含む）
  def update
    # チェックボックス等で画像削除を明示的に行う場合（オプション）
    if params[:remove_image] == "1"
      @product.image.purge if @product.image.attached?
    end

    if @product.update(product_params)
      redirect_to products_path, notice: "商品情報を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # 削除処理
  def destroy
    @product.destroy
    redirect_to products_path, notice: "商品を削除しました。"
  end

  private

  # IDから商品を取得（編集/表示/削除時に使用）
  def set_product
    @product = Product.find(params[:id])
  end

  # 許可されたパラメータ
  def product_params
    params.require(:product).permit(:name, :price, :image)
  end

  def remove_image
    @product = Product.find(params[:id])
    @product.image.purge
    redirect_to edit_product_path(@product), notice: "画像を削除しました"
  end


end
