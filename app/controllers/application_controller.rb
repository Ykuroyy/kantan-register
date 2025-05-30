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

  def current_cart
    session[:cart] ||= []
  end

  def cart_items
    current_cart.map do |item|
      product = Product.find_by(id: item["product_id"])
      quantity = item["quantity"].to_i
      subtotal = product&.price.to_i * quantity

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
