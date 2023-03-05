# frozen_string_literal: true

require 'minitest/autorun'
require 'callstacking/rails/settings'

module Callstacking
  module Rails
    module Client
      class TraceTest < Minitest::Test
        def setup
          @subject = Callstacking::Rails::Client::Trace.new
        end

        def test_create
          Async do
            trace_id, pulse_interval, max_trace_entries = @subject.create('index', 'HomeController', 'index', 'html', '/', 'https://example.com', '123456', {}, {})
            assert trace_id.is_a?(String)
            assert pulse_interval.is_a?(Integer)
            assert max_trace_entries.is_a?(Integer)
          end.wait
        end
      end
    end
  end
end