# frozen_string_literal: true

# Builds the object that executes a pending order.
class OrderExecutorFactory
  def self.build(order)
    ExecuteOrder.new(order)
  end
end
