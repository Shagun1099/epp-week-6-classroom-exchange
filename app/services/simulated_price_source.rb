# frozen_string_literal: true

require "digest"

# Returns a deterministic simulated quote for a stock. The price moves by a
# small percentage each day, derived from a hash of the ticker and the date so
# the same inputs always produce the same output.
class SimulatedPriceSource
  def fetch_quote(symbol)
    stock = Stock.find_by(ticker: symbol)
    return nil unless stock

    today = Date.today
    new_price_cents = compute_price_cents(stock.price_cents, symbol, today)

    {
      "05. price" => format("%.4f", new_price_cents / 100.0),
      "07. latest trading day" => today.to_s
    }
  end

  private

  def compute_price_cents(current_price_cents, symbol, date)
    seed = Digest::SHA2.hexdigest("#{symbol}-#{date}").to_i(16) % 401
    change_pct = (seed - 200) / 10_000.0  # -2.00% to +2.00%
    [(current_price_cents * (1.0 + change_pct)).round, 1].max
  end
end
