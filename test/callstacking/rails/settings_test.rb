# frozen_string_literal: true

require 'minitest/autorun'

module Callstacking
  module Rails
    class SettingsTest < Minitest::Test
      def setup
        @subject = Callstacking::Rails::Settings.new
      end

      def test_read_settings
        assert_equal @subject.url, Callstacking::Rails::Settings::PRODUCTION_URL
      end
    end
  end
end
