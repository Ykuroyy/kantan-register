class OrdersController < ApplicationController
  # 注文完了画面
  def complete
    @order = Order.find(params[:id])
  end

  # 売上分析ダッシュボード
  def analytics
    # 1) 期間選択（daily / monthly / annual）
    @period = params[:period] || "daily"

    case @period
    when "annual"
      # 年別：今年 1/1 ～ 12/31
      start_date = Time.zone.today.beginning_of_year
      end_date   = Time.zone.today.end_of_year

      label_proc = ->(d) { d.year.to_s }
      key_proc   = ->(d) { d.year.to_s }

      raw_sales = Order
                  .where(created_at: start_date..end_date)
                  .group("YEAR(created_at)")
                  .sum(:total_price)

    when "monthly"
      # 月別：今月 1日 ～ 月末
      start_date = Time.zone.today.beginning_of_month
      end_date   = Time.zone.today.end_of_month

      label_proc = ->(d) { d.strftime("%-m/%-d") }
      key_proc   = ->(d) { d.strftime("%Y-%m") }

      raw_sales = Order
                  .where(created_at: start_date..end_date)
                  .group("DATE_FORMAT(created_at, '%Y-%m')")
                  .sum(:total_price)

    else
      # 日別：過去 7 日分（昨日まで）
      yday        = Time.zone.today - 1.day
      start_date  = yday - 6.days
      end_date    = yday

      label_proc = ->(d) { d.strftime("%-m/%-d") }
      key_proc   = ->(d) { d }

      raw_sales = Order
                  .where(created_at: start_date..end_date)
                  # PostgreSQL 用に to_char() で「YYYY-MM」形式をキーに
                  .group("to_char(created_at, 'YYYY-MM')")
                  .sum(:total_price)
    end

    # 2) ラベル／データをゼロ埋め
    @period_labels = (start_date..end_date).map(&label_proc)
    @period_data   = (start_date..end_date).map { |d| raw_sales[key_proc.call(d)] || 0 }

    # 3) サマリー指標
    scope = Order.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    @total_sales      = @period_data.sum
    @total_orders     = scope.count
    @total_items      = scope.joins(:order_items).sum("order_items.quantity")
    @average_purchase = @total_orders.positive? ? (@total_sales.to_f / @total_orders).round(2) : 0

    # 4) 商品別販売数
    @product_sales = OrderItem.joins(:order, :product)
                              .where(orders: { created_at: start_date.beginning_of_day..end_date.end_of_day })
                              .group("products.name")
                              .sum(:quantity)
  end
end
