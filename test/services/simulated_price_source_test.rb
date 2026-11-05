# frozen_string_literal: true

require "test_helper"

class SimulatedPriceSourceTest < ActiveSupport::TestCase
  setup do
    @source = SimulatedPriceSource.new
    @stock = create(:stock, ticker: "FAKE", price_cents: 10_000)
  end

  test "returns a hash with price and trading day keys" do
    result = @source.fetch_quote("FAKE")

    assert_not_nil result
    assert result.key?("05. price")
    assert result.key?("07. latest trading day")
  end

  test "trading day is today's date" do
    result = @source.fetch_quote("FAKE")

    assert_equal Date.today.to_s, result["07. latest trading day"]
  end

  test "price is deterministic for the same stock and trading day" do
    result1 = @source.fetch_quote("FAKE")
    result2 = @source.fetch_quote("FAKE")

    assert_equal result1["05. price"], result2["05. price"]
  end

  test "price differs for different tickers on the same day" do
    create(:stock, ticker: "OTHR", price_cents: 10_000)

    result_fake = @source.fetch_quote("FAKE")
    result_othr = @source.fetch_quote("OTHR")

    assert_not_equal result_fake["05. price"], result_othr["05. price"]
  end

  test "price moves by at most 2 percent from the current price" do
    result = @source.fetch_quote("FAKE")
    new_price_cents = (result["05. price"].to_f * 100).round

    assert_operator new_price_cents, :>=, 9_800   # -2%
    assert_operator new_price_cents, :<=, 10_200   # +2%
  end

  test "returns nil for an unknown ticker" do
    result = @source.fetch_quote("UNKN")

    assert_nil result
  end
end
