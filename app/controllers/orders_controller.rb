# app/controllers/orders_controller.rb
class OrdersController < ApplicationController
  def analytics
    @period = params[:period].presence_in(%w[annual monthly daily]) || "daily"

    today = Time.zone.today
    case @period
    when "annual"
      start_date = today.beginning_of_year
      end_date   = today.end_of_year
      pg_fmt     = "YYYY"
      pg_trunc   = "year"
    when "monthly"
      start_date = today.beginning_of_month
      end_date   = today.end_of_month
      pg_fmt     = "YYYY-MM"
      pg_trunc   = "month"
    else
      start_date = today
      end_date   = today
      pg_fmt     = "YYYY-MM-DD"
      pg_trunc   = "day"
    end

    # 🧠 PostgreSQLの created_at を JST に変換してグループ化
    date_expr = Arel.sql("to_char(DATE_TRUNC('#{pg_trunc}', orders.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo'), '#{pg_fmt}')")

    # ✅ created_at も JSTにあわせて範囲を指定
    utc_start = start_date.beginning_of_day.in_time_zone("Asia/Tokyo").utc
    utc_end   = end_date.end_of_day.in_time_zone("Asia/Tokyo").utc

    rows = OrderItem
           .joins(:product, :order)
           .where(orders: { created_at: utc_start..utc_end })
           .group(date_expr)
           .order(date_expr)
           .sum("order_items.quantity * products.price")

    @period_labels = rows.keys
    @period_data   = rows.values

    scope = Order.where(created_at: utc_start..utc_end)
    @total_sales      = @period_data.sum
    @total_orders     = scope.count
    @total_items      = scope.joins(:order_items).sum("order_items.quantity")
    @average_purchase = @total_orders.positive? ? (@total_sales.to_f / @total_orders).round(2) : 0

    @product_sales = OrderItem
                     .joins(:order, :product)
                     .where(orders: { created_at: utc_start..utc_end })
                     .group("products.name")
                     .sum(:quantity)

    @sales_data = OrderItem
                  .joins(:order, :product)
                  .where(orders: { created_at: utc_start..utc_end })
                  .group("products.name")
                  .sum("order_items.quantity * products.price")
  end
end
