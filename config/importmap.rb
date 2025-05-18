## Pin npm packages by running ./bin/importmap

pin "application"

# Turboを使用（Rails 7の標準）
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true

# プレビュー機能用のJavaScript
pin "preview"

# rails-ujsへの参照を削除
# pin "@rails/ujs", to: "rails-ujs.js"