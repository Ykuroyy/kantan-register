class OrdersController < ApplicationController
  # 注文完了画面
  def complete
    @order = Order.find(params[:id])
  end


  PERIOD_MAP = { "annual" => :year, "monthly" => :month, "daily" => :day }.freeze

  def analytics
    @period = params[:period].presence_in(PERIOD_MAP.keys) || "daily"

    # 集計期間とフォーマット文字列を設定
    today = Time.zone.today
    case @period
    when "annual"
      start_date = today.beginning_of_year
      end_date   = today.end_of_year
      fmt        = "%Y"
    when "monthly"
      start_date = today.beginning_of_month
      end_date   = today.end_of_month
      fmt        = "%Y-%m"
    else
      end_date   = today - 1.day
      start_date = end_date - 6.days
      fmt        = "%Y-%m-%d"
    end

    # 生の SQL を Arel.sql でラップ
    date_expr = Arel.sql("DATE_FORMAT(order_items.created_at, '#{fmt}')")

    rows = OrderItem
           .joins(:product)
           .where(order_items: { created_at: start_date.beginning_of_day..end_date.end_of_day })
           .group(date_expr)
           .order(date_expr)
           .sum("order_items.quantity * products.price")

    @period_labels = rows.keys
    @period_data   = rows.values

    # サマリー指標
    scope = Order.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    @total_sales      = @period_data.sum
    @total_orders     = scope.count
    @total_items      = scope.joins(:order_items).sum("order_items.quantity")
    @average_purchase = @total_orders.positive? ? (@total_sales.to_f / @total_orders).round(2) : 0

    # 商品別販売数
    @product_sales = OrderItem
                     .joins(:order, :product)
                     .where(orders: { created_at: start_date.beginning_of_day..end_date.end_of_day })
                     .group("products.name")
                     .sum(:quantity)
  end
end
