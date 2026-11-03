# frozen_string_literal: true

class TransactionFeeProcessor
  def initialize(orders, fee_strategy: FlatTransactionFee.new)
    @orders = orders
    @fee_strategy = fee_strategy
    @users = Set.new
  end

  def self.execute(...)
    new(...).execute
  end

  def execute
    ActiveRecord::Base.transaction do
      @orders.each do |order|
        add_transaction_fee order
      end
    end
  end

  private

  def add_transaction_fee(order)
    return if @users.include?(order.portfolio.user_id)

    order.portfolio.portfolio_transactions.fees.create!(
      amount_cents: @fee_strategy.fee_cents_for(order.portfolio),
      reason: :transaction_fees
    )
    @users << order.portfolio.user_id
  end
end
