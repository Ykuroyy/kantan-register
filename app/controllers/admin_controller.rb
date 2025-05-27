class AdminController < ApplicationController
  # CSRF トークンチェックは飛ばす
  skip_before_action :verify_authenticity_token

  RESET_TOKEN = ENV.fetch("RESET_TOKEN")

  def reset_all
    # クエリパラメータ ?token=xxxx がない or 間違ってたら 401
    return head :unauthorized unless params[:token] == RESET_TOKEN

    # カート・注文関連
    CartItem.delete_all
    OrderItem.delete_all
    Order.delete_all

    # ActiveStorage の関連レコード
    ActiveStorage::VariantRecord.delete_all
    ActiveStorage::Attachment.delete_all
    ActiveStorage::Blob.delete_all

    # 商品
    Product.delete_all

    render plain: "🚨 リセット完了！", status: :ok
  end
end
