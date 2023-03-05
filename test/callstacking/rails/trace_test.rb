# frozen_string_literal: true

require 'minitest/autorun'
require 'callstacking/rails/settings'

module Callstacking
  module Rails
    class TraceTest < Minitest::Test
      def setup
        @spans   = Spans.new
        @subject = Callstacking::Rails::Trace.new(@spans)
      end

      def test_do_not_track_request
        assert_equal true,
                     @subject.send(:do_not_track_request?, 'http://localhost:3000/assets/application.css', 'text/css')
        assert_equal true,
                     @subject.send(:do_not_track_request?, 'http://localhost:3000/health', '*/*')
        assert_equal false,
                     @subject.send(:do_not_track_request?, 'http://localhost:3000/users', 'text/html')
      end
    end
  end
end
