class ReportsController < ApplicationController
  def index
    # 1. 全注文をロードしてローカル日付でグループ化
    raw_daily = Order.all
                     .group_by { |o| o.created_at.to_date }
                     .transform_values { |orders| orders.sum(&:total_price) }

    # 2. 過去７日分を日付レンジで用意し、ゼロ埋め
    today      = Time.zone.today
    start_date = today - 6.days
    range      = (start_date..today)
    @daily_sales = range.each_with_object({}) do |date, h|
      h[date] = raw_daily[date] || 0
    end

    # 3. 全期間 商品別販売数集計（グラフ用）
    @product_sales = OrderItem
                     .joins(:product)
                     .group("products.name")
                     .sum(:quantity)

    # 4. 当月と本日の商品別販売数（テーブル用）
    @monthly_product_sales = OrderItem
                             .joins(:order, :product)
                             .where(orders: { created_at: today.beginning_of_month..today.end_of_day })
                             .group("products.name")
                             .sum(:quantity)

    @today_product_sales = OrderItem
                           .joins(:order, :product)
                           .where(orders: { created_at: today.beginning_of_day..Time.zone.now })
                           .group("products.name")
                           .sum(:quantity)

    # 5. サマリー指標計算
    @total_sales         = @daily_sales.values.sum
    @total_orders        = Order.count
    @average_order_value = @total_orders.positive? ? (@total_sales.to_f / @total_orders).round(2) : 0
    @daily_average_sales = @daily_sales.size.positive? ? (@total_sales.to_f / @daily_sales.size).round(2) : 0

    if @daily_sales.present?
      max_day, max_value = @daily_sales.max_by { |_, v| v }
      min_day, min_value = @daily_sales.min_by { |_, v| v }
      @max_sales_day   = max_day.strftime("%-m/%-d")
      @max_sales_value = max_value
      @min_sales_day   = min_day.strftime("%-m/%-d")
      @min_sales_value = min_value
    end

    # 6. 本日売上
    @today_sales = @daily_sales[today] || 0
  end
end
