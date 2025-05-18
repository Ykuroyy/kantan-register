require 'rails_helper'

RSpec.describe Product, type: :model do
  describe 'Product Registration' do
    let(:product) { FactoryBot.build(:product) }

    context 'when the content is valid' do
      it 'is valid with all required attributes' do
        expect(product).to be_valid
      end

      it 'is valid even if image is not attached' do
        product.image = nil
        expect(product).to be_valid
      end
    end

    context 'when the content is invalid' do
      it 'is invalid without a name' do
        product.name = ''
        product.valid?
        expect(product.errors.full_messages).to include("Name can't be blank")
      end

      it 'is invalid if name is over 40 characters' do
        product.name = 'a' * 41
        product.valid?
        expect(product.errors.full_messages).to include("Name is too long (maximum is 40 characters)")
      end

      it 'is invalid without a price' do
        product.price = nil
        product.valid?
        expect(product.errors.full_messages).to include("Price can't be blank")
      end

      it 'is invalid if price is 0 or less' do
        product.price = 0
        product.valid?
        expect(product.errors.full_messages).to include("Price must be greater than 0")
      end

      it 'is invalid if price is over 9,999,999' do
        product.price = 10_000_000
        product.valid?
        expect(product.errors.full_messages).to include("Price must be less than or equal to 9999999")
      end

      it 'is invalid if price is a decimal' do
        product.price = 1234.56
        product.valid?
        expect(product.errors.full_messages).to include("Price must be an integer")
      end
    end
  end
end
