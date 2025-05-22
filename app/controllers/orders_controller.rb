class OrdersController < ApplicationController
  def complete
    @order = Order.find(params[:id])
  end
end
