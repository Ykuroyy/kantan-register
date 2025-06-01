# app/controllers/orders_controller.rb
class OrdersController < ApplicationController
  def analytics
    @period = params[:period].presence_in(%w[annual monthly daily]) || "daily"

    today = Time.zone.today # JSTの今日の日付

    case @period
    when "annual"
      start_date = today.beginning_of_year
      end_date   = today.end_of_year
      pg_fmt     = "YYYY" # PostgreSQLのto_charフォーマット
      pg_trunc   = "year"
    when "monthly"
      start_date = today.beginning_of_month
      end_date   = today.end_of_month
      pg_fmt     = "YYYY-MM" # PostgreSQLのto_charフォーマット
      pg_trunc   = "month"
    else # "daily"
      start_date = today          # JSTの今日の日付
      end_date   = today          # JSTの過去7日間の終了日（今日）
      pg_fmt     = "YYYY-MM-DD" # PostgreSQLのto_charフォーマット
      pg_trunc   = "day"
    end

    # 🧠 PostgreSQLの created_at (UTC) を JST に変換してグループ化するための式
    # DATE_TRUNCで指定された単位（年/月/日）に丸め、to_charで指定されたフォーマットの文字列に変換
    date_expr = Arel.sql("to_char(DATE_TRUNC('#{pg_trunc}', orders.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Tokyo'), '#{pg_fmt}')")

    # ✅ DBクエリ用の期間指定 (UTCに変換)
    # start_date と end_date はJSTなので、DBのcreated_at(UTC)と比較するためにUTCに変換
    utc_start = start_date.beginning_of_day.in_time_zone("Asia/Tokyo").utc
    utc_end   = end_date.end_of_day.in_time_zone("Asia/Tokyo").utc

    # グラフ用の売上データをDBから取得
    # キーは date_expr で指定した JST の日付文字列 (pg_fmt形式)
    sales_by_period_from_db = OrderItem
                              .joins(:product, :order)
                              .where(orders: { created_at: utc_start..utc_end }) # 期間はUTCで絞り込み
                              .group(date_expr) # JST変換後の日付文字列でグループ化
                              .order(date_expr) # 日付順にソート
                              .sum("order_items.quantity * products.price")

    if @period == "daily"
      @period_labels = []
      @period_data   = []
      # 日別表示の場合: start_date(JST) から end_date(JST) までのすべての日付をラベルとし、売上がない日は0とする
      (start_date..end_date).each do |date_in_jst|
        # DBから取得したデータのキー形式 (pg_fmt) に合わせるため、strftimeのフォーマットも変換
        # pg_fmt の 'YYYY', 'MM', 'DD' を strftime の '%Y', '%m', '%d' に置換
        strftime_format = pg_fmt.gsub('YYYY', '%Y').gsub('MM', '%m').gsub('DD', '%d')
        label_key = date_in_jst.strftime(strftime_format)

        @period_labels << label_key
        @period_data   << (sales_by_period_from_db[label_key] || 0)
      end
    else
      # 月間・年間表示の場合: DBから取得した結果をそのまま使用
      # (売上がない月・年は表示されないが、これは許容範囲とする)
      @period_labels = sales_by_period_from_db.keys
      @period_data   = sales_by_period_from_db.values
    end

    # ── サマリー指標・商品別集計 ────────────────────────────
    # scope はDBクエリ用の期間 (utc_start..utc_end) を使用
    scope = Order.where(created_at: utc_start..utc_end)

    @total_sales      = @period_data.sum # @period_data は日別の場合0埋めされているので合計は正しい
    @total_orders     = scope.count
    @total_items      = scope.joins(:order_items).sum("order_items.quantity")
    @average_purchase = @total_orders.positive? ? (@total_sales.to_f / @total_orders).round(2) : 0

    @product_sales = OrderItem # 商品別「数量」
                     .joins(:order, :product)
                     .where(orders: { created_at: utc_start..utc_end }) # 期間はUTCで絞り込み
                     .group("products.name")
                     .sum(:quantity)

    @sales_data = OrderItem # 商品別「金額」
                  .joins(:order, :product)
                  .where(orders: { created_at: utc_start..utc_end }) # 期間はUTCで絞り込み
                  .group("products.name")
                  .sum("order_items.quantity * products.price")
  end

  # 他の注文関連のアクション（例: completeなど）があればここに記述
  def complete
    @order = Order.find(params[:id])
    # 必要に応じて他の処理
  end
end
