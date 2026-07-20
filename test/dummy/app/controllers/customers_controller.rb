class CustomersController < ApplicationController
  before_action :set_customer, only: %i[show edit update destroy]
  before_action :set_navigation, only: %i[show edit]

  # GET /customers
  def index
  end

  # GET /customers/1
  def show
  end

  # GET /customers/new
  def new
    @customer = Customer.new
  end

  # GET /customers/1/edit
  def edit
  end

  # POST /customers
  def create
    @customer = Customer.new(customer_params)

    if @customer.save
      redirect_to @customer, notice: "Customer was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /customers/1
  def update
    if @customer.update(customer_params)
      redirect_to @customer, notice: "Customer was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /customers/1
  def destroy
    @customer.destroy!
    redirect_to customers_path, notice: "Customer was successfully destroyed.", status: :see_other
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_customer
    @customer = Customer.find(params.expect(:id))
  end

  def set_navigation
    @mensa_table = traversed_mensa_table(:customers)
    @mensa_navigation_params = mensa_navigation_params
    @previous_customer = @mensa_table.previous_record(@customer)
    @next_customer = @mensa_table.next_record(@customer)
  end

  # Only allow a list of trusted parameters through.
  def customer_params
    params.expect(customer: [:country, :isin, :name, :stock_symbol])
  end
end
