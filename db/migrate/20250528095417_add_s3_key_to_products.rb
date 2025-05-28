class AddS3KeyToProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :s3_key, :string
  end
end
