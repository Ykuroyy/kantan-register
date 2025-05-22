# config/initializers/number_to_currency.rb

module YenCurrencyFormatter
  def number_to_currency(number, options = {})
    super(number, {
      unit: "¥",
      format: "%u%n",
      precision: 0,      # 小数点以下なし
      delimiter: ",",    # 3桁区切り（1,000）
    }.merge(options))
  end
end

ActionView::Base.prepend(YenCurrencyFormatter)
