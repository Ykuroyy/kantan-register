class OrdersController < ApplicationController
  PERIOD_MAP = { "annual" => :year, "monthly" => :month, "daily" => :day }.freeze

  def analytics
    @period = params[:period].presence_in(PERIOD_MAP.keys) || "daily"

    today = Time.zone.today

    # ── 期間ごとの開始・終了日時、フォーマット指定 ──
    case @period
    when "annual"
      start_date = today.beginning_of_year
      end_date   = today.end_of_year
      mysql_fmt  = "%Y"
      pg_fmt     = "YYYY"
    when "monthly"
      start_date = today.beginning_of_month
      end_date   = today.end_of_month
      mysql_fmt  = "%Y-%m"
      pg_fmt     = "YYYY-MM"
    else # daily
      start_date = today
      end_date   = today
      mysql_fmt  = "%Y-%m-%d"
      pg_fmt     = "YYYY-MM-DD"
    end

    # ── DBアダプタによって日付の文字列変換SQLを切り替え ──
    adapter = ActiveRecord::Base.connection.adapter_name.downcase
    date_sql =
      if adapter.include?("mysql")
        "DATE_FORMAT(orders.created_at, '#{mysql_fmt}')"
      else
        "to_char(DATE_TRUNC('#{PERIOD_MAP[@period]}', orders.created_at), '#{pg_fmt}')"
      end
    date_expr = Arel.sql(date_sql)

    # ── 期間別売上集計（グラフ用）────────────────
    rows = OrderItem
           .joins(:product, :order)
           .where(orders: { created_at: start_date.beginning_of_day..end_date.end_of_day })
           .group(date_expr)
           .order(date_expr)
           .sum("order_items.quantity * products.price")

    @period_labels = rows.keys
    @period_data   = rows.values

    # ── サマリー値 ───────────────────────────────
    scope = Order.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    @total_sales      = @period_data.sum
    @total_orders     = scope.count
    @total_items      = scope.joins(:order_items).sum("order_items.quantity")
    @average_purchase = @total_orders.positive? ? (@total_sales.to_f / @total_orders).round(2) : 0

    # ── 商品別販売数 ─────────────────────────────
    @product_sales = OrderItem
                     .joins(:order, :product)
                     .where(orders: { created_at: start_date.beginning_of_day..end_date.end_of_day })
                     .group("products.name")
                     .sum(:quantity)

    # ── 商品別売上金額 ───────────────────────────
    @sales_data = OrderItem
                  .joins(:product, :order)
                  .where(orders: { created_at: start_date.beginning_of_day..end_date.end_of_day })
                  .group("products.name")
                  .sum("order_items.quantity * products.price")
  end
end
