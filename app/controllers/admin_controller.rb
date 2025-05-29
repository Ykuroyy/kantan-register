class AdminController < ApplicationController
  # 管理画面は Basic 認証を通っている想定
  skip_before_action :verify_authenticity_token

  RESET_TOKEN = ENV.fetch("RESET_TOKEN")

  def reset_all
    return head :unauthorized unless params[:token] == RESET_TOKEN

    CartItem.delete_all
    OrderItem.delete_all
    Order.delete_all

    ActiveStorage::VariantRecord.delete_all
    ActiveStorage::Attachment.delete_all
    ActiveStorage::Blob.delete_all

    Product.delete_all

    render plain: "🚨 リセット完了！", status: :ok
  end
end
