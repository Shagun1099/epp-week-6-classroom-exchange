# frozen_string_literal: true

class FlatTransactionFee < TransactionFeeStrategy
  def fee_cents_for(_portfolio)
    PortfolioTransaction::TRANSACTION_FEE_CENTS
  end
end
