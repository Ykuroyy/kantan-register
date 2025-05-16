class ProductsController < ApplicationController
  before_action :set_product, only: [:show, :edit, :update, :destroy]
  
  def index
    @products = Product.all
  end

  def show
  end

  def new
    @product = Product.new
  end

  def edit
  end
  

  def create
    @product = Product.new(product_params)

    if @product.save
      redirect_to @product, notice: '商品が正常に登録されました。'
    else
      render :new
    end
  end

  def update
    if @product.update(product_params)
      redirect_to @product, notice: '商品が正常に更新されました。'
    else
      render :edit
    end
  end

  def destroy
    @product.destroy
    redirect_to products_url, notice: '商品が正常に削除されました。'
  end



  def remove_image
    @product = Product.find(params[:id])
    @product.image.purge if @product.image.attached?
    redirect_to edit_product_path(@product), notice: "画像を削除しました"
  end



  private
    def set_product
      @product = Product.find(params[:id])
    end

    def product_params
      params.require(:product).permit(:name, :price, :image)
    end  


end
