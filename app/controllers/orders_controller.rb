class OrdersController < ApplicationController
  # 注文完了画面
  def complete
    @order = Order.find(params[:id])
  end


  PERIOD_MAP = { "annual" => :year, "monthly" => :month, "daily" => :day }.freeze

  def analytics
    @period = params[:period].presence_in(PERIOD_MAP.keys) || "daily"

    # ── 集計期間とフォーマット文字列 ────────────────────
    today = Time.zone.today
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
    else
      end_date   = today
      start_date = end_date - 6.days
      mysql_fmt  = "%Y-%m-%d"
      pg_fmt     = "YYYY-MM-DD"
    end

    # ── adapter ごとに日付文字列生成を切り替え ──────────────
    adapter = ActiveRecord::Base.connection.adapter_name.downcase
    date_sql =
      if adapter.include?("mysql")
        "DATE_FORMAT(order_items.created_at, '#{mysql_fmt}')"
      else
        # PostgreSQL
        "to_char(order_items.created_at, '#{pg_fmt}')"
      end
    date_expr = Arel.sql(date_sql)

    # ── 集計クエリ ───────────────────────────────────────
    rows = OrderItem
           .joins(:product)
           .where(order_items: { created_at: start_date.beginning_of_day..end_date.end_of_day })
           .group(date_expr)
           .order(date_expr)
           .sum("order_items.quantity * products.price")

    @period_labels = rows.keys
    @period_data   = rows.values

    # ── 以下、サマリー指標・商品別集計は変わらず ────────────
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

    # ✅ 商品別売上ランキングデータ（合計金額でソート）
    @sales_data = OrderItem
                  .joins(:product)
                  .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
                  .group(:product_id)
                  .select("product_id, SUM(quantity * products.price) AS total")
                  .includes(:product)
                  .order("total DESC")
  end
end
