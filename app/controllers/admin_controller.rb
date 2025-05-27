# app/controllers/admin_controller.rb
class AdminController < ApplicationController
  # CSRF トークンチェックは飛ばす
  skip_before_action :verify_authenticity_token

  RESET_TOKEN = ENV.fetch("RESET_TOKEN")

  def reset_all
    # token チェック
    return head :unauthorized unless params[:token] == RESET_TOKEN

    # ——— 注文明細と注文を削除 ———
    OrderItem.delete_all if defined?(OrderItem)
    Order.delete_all     if defined?(Order)

    # ——— ActiveStorage の関連テーブルを削除 ———
    ActiveStorage::VariantRecord.delete_all
    ActiveStorage::Attachment.delete_all
    ActiveStorage::Blob.delete_all

    # ——— 商品を全件削除 ———
    Product.delete_all

    # ——— セッション内のカートもクリア ———
    reset_session

    render plain: "🚨 リセット完了！", status: :ok
  end
end
