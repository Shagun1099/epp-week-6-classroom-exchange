# frozen_string_literal: true

require "test_helper"

module Admin
  class TestSettingsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = create(:admin, admin: true)
      sign_in(@admin)
    end

    teardown do
      ENV.delete("CX_TEST_SETTINGS")
    end

    test "is not found when test settings are off" do
      get admin_test_settings_path

      assert_response :not_found
    end

    test "shows the page when test settings are on" do
      ENV["CX_TEST_SETTINGS"] = "on"

      get admin_test_settings_path

      assert_response :success
      assert_select "h1", "Test settings"
    end

    test "runs pending orders when test settings are on" do
      ENV["CX_TEST_SETTINGS"] = "on"
      OrderExecutionJob.expects(:perform_now).once

      post run_pending_orders_admin_test_settings_path

      assert_redirected_to admin_test_settings_path
    end
  end
end
