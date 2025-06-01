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
    else # "daily"
      start_date = today
      end_date   = today
      pg_fmt     = "YYYY-MM-DD"
      pg_trunc   = "day"
    end

    # JSTとして比較するためのWHERE句（UTC→JST変換）
    where_clause = [
      "orders.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo' BETWEEN ? AND ?",
      start_date.beginning_of_day,
      end_date.end_of_day
    ]

    # グラフ表示用
    date_expr = Arel.sql("to_char(DATE_TRUNC('#{pg_trunc}', orders.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo'), '#{pg_fmt}')")

    sales_by_period_from_db = OrderItem
                              .joins(:product, :order)
                              .where(where_clause)
                              .group(date_expr)
                              .order(date_expr)
                              .sum("order_items.quantity * products.price")

    if @period == "daily"
      @period_labels = []
      @period_data   = []

      (start_date..end_date).each do |date_in_jst|
        format = pg_fmt.gsub('YYYY', '%Y').gsub('MM', '%m').gsub('DD', '%d')
        label  = date_in_jst.strftime(format)

        @period_labels << label
        @period_data   << (sales_by_period_from_db[label] || 0)
      end
    else
      @period_labels = sales_by_period_from_db.keys
      @period_data   = sales_by_period_from_db.values
    end

    # --- 集計データ（JST比較） ---
    scope = Order.where(where_clause)

    @total_sales      = @period_data.sum
    @total_orders     = scope.count
    @total_items      = scope.joins(:order_items).sum("order_items.quantity")
    @average_purchase = @total_orders.positive? ? (@total_sales.to_f / @total_orders).round(2) : 0

    @product_sales = OrderItem
                     .joins(:order, :product)
                     .where(where_clause)
                     .group("products.name")
                     .sum(:quantity)

    @sales_data = OrderItem
                  .joins(:order, :product)
                  .where(where_clause)
                  .group("products.name")
                  .sum("order_items.quantity * products.price")

    # ログ確認用（必要に応じて残す）
    Rails.logger.info "🧪 Period: #{@period}, Labels: #{@period_labels.inspect}, Data: #{@period_data.inspect}"
  end

  def complete
    @order = Order.find(params[:id])
  end
end
