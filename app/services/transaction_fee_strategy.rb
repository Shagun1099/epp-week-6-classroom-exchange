# frozen_string_literal: true

# How much a student pays in trading fees for one batch of orders.
# Subclasses decide the amount.
class TransactionFeeStrategy
  def fee_cents_for(_portfolio)
    raise NotImplementedError, "#{self.class} must implement fee_cents_for"
  end
end
