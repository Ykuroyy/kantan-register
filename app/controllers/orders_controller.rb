# app/controllers/orders_controller.rb
class OrdersController < ApplicationController
  PERIOD_MAP = { "annual" => :year, "monthly" => :month, "daily" => :day }.freeze

  def analytics
    @period = params[:period].presence_in(PERIOD_MAP.keys) || "daily"
    today = Time.zone.today

    # ── JSTでの集計期間設定 ──
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
    else # daily
      start_date = today
      end_date   = today
      pg_fmt     = "YYYY-MM-DD"
      pg_trunc   = "day"
    end

    # ── PostgreSQLで created_at を JST に変換して集計 ──
    date_sql = <<~SQL.squish
      to_char(DATE_TRUNC('#{pg_trunc}', orders.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo'), '#{pg_fmt}')
    SQL
    date_expr = Arel.sql(date_sql)

    rows = OrderItem
           .joins(:product, :order)
           .where(orders: { created_at: start_date.beginning_of_day..end_date.end_of_day })
           .group(date_expr)
           .order(date_expr)
           .sum("order_items.quantity * products.price")

    @period_labels = rows.keys
    @period_data   = rows.values

    scope = Order.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    @total_sales      = @period_data.sum
    @total_orders     = scope.count
    @total_items      = scope.joins(:order_items).sum("order_items.quantity")
    @average_purchase = @total_orders.positive? ? (@total_sales.to_f / @total_orders).round(2) : 0

    @product_sales = OrderItem
                     .joins(:order, :product)
                     .where(orders: { created_at: start_date.beginning_of_day..end_date.end_of_day })
                     .group("products.name")
                     .sum(:quantity)

    @sales_data = OrderItem
                  .joins(:product, :order)
                  .where(orders: { created_at: start_date.beginning_of_day..end_date.end_of_day })
                  .group("products.name")
                  .sum("order_items.quantity * products.price")
  end
end
