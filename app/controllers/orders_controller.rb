# app/controllers/orders_controller.rb
class OrdersController < ApplicationController
  # 注文完了画面
  def complete
    @order = Order.find(params[:id])
  end

  PERIOD_MAP = { "annual" => :year, "monthly" => :month, "daily" => :day }.freeze

  # 売上分析ダッシュボード
  def analytics
    param_key = params[:period].presence_in(PERIOD_MAP.keys) || "daily"
    group_key = PERIOD_MAP[param_key]            # :year / :month / :day
    @period   = param_key                        # ビュー側（タブ判定）で使う

    # ── 期間範囲を決定 ─────────────────────────
    today = Time.zone.today
    case @period
    when "annual"
      start_date = today.beginning_of_year
      end_date   = today.end_of_year
    when "monthly"
      start_date = today.beginning_of_month
      end_date   = today.end_of_month
    else # daily → 過去 7 日（昨日まで）
      end_date   = today - 1.day
      start_date = end_date - 6.days
    end

    # ── Groupdate で期間別売上 ────────────────
    rows = Order
           .joins(order_items: :product) # products を JOIN
           .where(created_at: start_date..end_date)
           .group_by_period(group_key,
                            :created_at,
                            range: start_date..end_date,
                            format: format_string(@period),
                            time_zone: Rails.env.development? ? false : true # ← ここを追加
                           )
           .sum("order_items.quantity * products.price")

    @period_labels = rows.keys
    @period_data   = rows.values

    # ── サマリー指標 ──────────────────────────
    scope              = Order.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    @total_sales       = @period_data.sum
    @total_orders      = scope.count
    @total_items       = scope.joins(:order_items).sum("order_items.quantity")
    @average_purchase  = @total_orders.positive? ? (@total_sales.to_f / @total_orders).round(2) : 0

    # ── 商品別販売数 ──────────────────────────
    @product_sales = OrderItem
                     .joins(:order, :product)
                     .where(orders: { created_at: start_date.beginning_of_day..end_date.end_of_day })
                     .group("products.name")
                     .sum(:quantity)
  end

  private

  # ラベル整形
  def format_string(period)
    case period
    when "annual"  then "%Y"        # 2025
    when "monthly" then "%Y-%m"     # 2025-05
    else                "%Y-%m-%d"  # 2025-05-24
    end
  end
end
