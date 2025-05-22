class OrdersController < ApplicationController
  def complete
    @order = Order.find(params[:id])
  end

  def sales_by_date
    @daily_sales = Order.group("DATE(created_at)").sum(:total_price)
  end

  def sales_by_product
    @product_sales = OrderItem.joins(:product)
                              .group("products.name")
                              .sum("order_items.quantity * products.price")
  end

  def sales_summary
    @total_sales = Order.sum(:total_price)
    @total_items = OrderItem.sum(:quantity)
    @top_product = OrderItem.joins(:product)
                            .group("products.name")
                            .order("SUM(quantity) DESC")
                            .limit(1)
                            .pluck("products.name")
                            .first
    @average_purchase = Order.average(:total_price).to_i
  end

  def analytics
    @daily_sales = Order.group("DATE(created_at)").sum(:total_price)
    @product_sales = OrderItem.joins(:product)
                              .group("products.name")
                              .sum("order_items.quantity * products.price")
    @total_sales = Order.sum(:total_price)
    @total_items = OrderItem.sum(:quantity)
    @top_product = OrderItem.joins(:product)
                            .group("products.name")
                            .order("SUM(quantity) DESC")
                            .limit(1)
                            .pluck("products.name")
                            .first
    @average_purchase = Order.average(:total_price).to_i
  end
end
