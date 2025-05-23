# app/controllers/orders_controller.rb
class OrdersController < ApplicationController
  def analytics
    # 1) period の選択（日別／月別／年別）
    @period = params[:period] || "daily"

    case @period
    when "annual"
      # 今年 1/1 〜 12/31, key は年度文字列、label は年度
      start_date = Time.zone.today.beginning_of_year
      end_date   = Time.zone.today.end_of_year
      label_proc = ->(d) { d.year.to_s }
      key_proc   = ->(d) { d.year.to_s }
      # SQL で年度ごとに集計
      raw_sales = Order
                  .where(created_at: start_date..end_date)
                  .group("YEAR(orders.created_at)")
                  .sum(:total_price)
    when "monthly"
      # 今月 1日 〜 月末, key は "YYYY-MM"、label は "M/DD"
      start_date = Time.zone.today.beginning_of_month
      end_date   = Time.zone.today.end_of_month
      label_proc = ->(d) { d.strftime("%-m/%-d") }
      key_proc   = ->(d) { d.strftime("%Y-%m") }
      # SQL で年月ごとに集計
      raw_sales = Order
                  .where(created_at: start_date..end_date)
                  .group("DATE_FORMAT(orders.created_at, '%Y-%m')")
                  .sum(:total_price)
    else
      # 過去７日（日別）→ Ruby 側で JST を使ってグルーピング
      today      = Time.zone.today
      start_date = today - 6.days
      end_date   = today
      label_proc = ->(d) { d.strftime("%-m/%-d") }
      key_proc   = ->(d) { d } # Date オブジェクトがキー
      # Ruby grouping so that created_at.in_time_zone.to_date is used
      raw_sales = Order
                  .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
                  .to_a
                  .group_by { |o| o.created_at.in_time_zone.to_date }
                  .transform_values { |orders| orders.sum(&:total_price) }
    end

    # 2) ラベルとデータをレンジでゼロ埋め
    @period_labels = (start_date..end_date).map(&label_proc)
    @period_data   = (start_date..end_date).map do |d|
      raw_sales[key_proc.call(d)] || 0
    end

    # 3) サマリー指標
    orders_scope      = Order.where(created_at: start_date..end_date.end_of_day)
    @total_sales      = @period_data.sum
    @total_orders     = orders_scope.count
    @total_items      = orders_scope.joins(:order_items).sum("order_items.quantity")
    @average_purchase = @total_orders.positive? ? (@total_sales.to_f / @total_orders).round(2) : 0

    # 4) 商品別販売数（同期間内）
    @product_sales = OrderItem.joins(:order, :product)
                              .where(orders: { created_at: start_date..end_date.end_of_day })
                              .group("products.name")
                              .sum(:quantity)
  end
end
