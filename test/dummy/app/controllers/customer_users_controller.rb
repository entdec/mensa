class CustomerUsersController < ApplicationController
  def index
    @customer = Customer.find(params[:customer_id])
  end
end
