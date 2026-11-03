# frozen_string_literal: true

# Controls for testers on the hosted copy. Only available when
# CX_TEST_SETTINGS is "on".
module Admin
  class TestSettingsController < BaseController
    before_action :require_test_settings

    def self.enabled?
      ENV["CX_TEST_SETTINGS"] == "on"
    end

    def show
      @pending_orders_count = Order.pending.count

      @breadcrumbs = [
        { label: "Test settings" }
      ]
    end

    def run_pending_orders
      count = Order.pending.count
      OrderExecutionJob.perform_now
      redirect_to admin_test_settings_path, notice: "Ran order execution for #{count} pending orders."
    end

    private

    def require_test_settings
      head :not_found unless self.class.enabled?
    end
  end
end
