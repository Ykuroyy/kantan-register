# db/migrate/YYYYMMDDHHMMSS_add_default_timestamps_to_products.rb# db/migrate/YYYYMMDDHHMMSS_add_default_timestamps_to_products.rb
class AddDefaultTimestampsToProducts < ActiveRecord::Migration[7.1]
  def change
    change_column_default :products, :created_at, from: nil, to: -> { "CURRENT_TIMESTAMP" }
    change_column_default :products, :updated_at, from: nil, to: -> { "CURRENT_TIMESTAMP" }
  end
end
