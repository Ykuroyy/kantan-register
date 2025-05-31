class ApplicationController < ActionController::Base
  before_action :basic_auth, if: :production?

  private


  def basic_auth
    authenticate_or_request_with_http_basic do |username, password|
     username == ENV["BASIC_AUTH_USER"] && password == ENV["BASIC_AUTH_PASSWORD"]
    end
  end

  def production?
    Rails.env.production?
  end

  def cart_items
    unless session[:cart].is_a?(Array) && session[:cart].all? { |i| i.is_a?(Hash) && i.key?("product_id") }
      Rails.logger.warn "⚠️ カート情報が不正なので初期化します: #{session[:cart].inspect}"
      session[:cart] = []
      return []
    end

    session[:cart].map do |item|
      product = Product.find_by(id: item["product_id"].to_i)
      quantity = item["quantity"].to_i
      subtotal = product&.price.to_i * quantity

      next unless product

      {
        product: product,
        quantity: quantity,
        subtotal: subtotal
      }
    end.compact
  end

  def calculate_total_price
    cart_items.sum { |item| item[:subtotal] }
  end

  def _add_to_cart(product_id)
    product = Product.find_by(id: product_id)
    return unless product

    existing = current_cart.find { |item| item["product_id"] == product.id }
    if existing
      existing["quantity"] += 1
    else
      current_cart << { "product_id" => product.id, "quantity" => 1 }
    end
  end
end
