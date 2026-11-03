# frozen_string_literal: true

# Keeps every stock lookup in one place, so controllers don't depend on
# how stocks are stored.
class StockRepository
  def self.find(id)
    Stock.find(id)
  end

  def self.find_by_ticker(ticker)
    Stock.find_by(ticker: ticker)
  end

  def self.active
    Stock.active
  end
end
