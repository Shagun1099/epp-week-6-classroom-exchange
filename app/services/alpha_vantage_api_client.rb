# frozen_string_literal: true

require "net/http"
require "json"

class AlphaVantageApiClient
  class ApiError < StandardError; end
  class InvalidResponseError < ApiError; end

  def initialize
    @api_key = ENV.fetch("ALPHA_VANTAGE_API_KEY", nil)
  end

  def fetch_quote(symbol)
    return nil unless api_key_present?

    Rails.logger.debug { "Fetching quote for #{symbol}" }

    data = make_request(symbol)
    extract_quote(data, symbol)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse API response for #{symbol}: #{e.message}"
    nil
  rescue StandardError => e
    Rails.logger.error "API request failed for #{symbol}: #{e.message}"
    nil
  end

  private

  def api_key_present?
    return true if @api_key

    Rails.logger.error "ALPHA_VANTAGE_API_KEY environment variable not configured"
    false
  end

  def make_request(symbol)
    url = build_url(symbol)
    uri = URI.parse(url)

    response = Net::HTTP.get(uri)
    JSON.parse(response)
  end

  def build_url(symbol)
    "https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=#{symbol}&apikey=#{@api_key}"
  end

  def extract_quote(data, symbol)
    quote = data&.dig("Global Quote")

    if quote.present?
      Rails.logger.info "API returned quote for #{symbol}"
      return quote
    end

    Rails.logger.error "Invalid API response for #{symbol}: #{data}"
    nil
  end
end
