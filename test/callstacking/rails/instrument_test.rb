# frozen_string_literal: true

require 'minitest/autorun'

module Callstacking
  module Rails
    class InstrumentTest < Minitest::Test
      def setup
        @spans = Callstacking::Rails::Spans.new
        @trace = Callstacking::Rails::Trace.new(@spans)
        @subject = Callstacking::Rails::Instrument.new(@spans)
      end

      def test_instrument_klass
        assert_match /app\/models\/salutation\.rb/, Salutation.instance_method(:hello).source_location.first

        @trace.expects(:create_call_entry).never
        @trace.expects(:create_call_return).never

        Salutation.new.hello('Jim')

        @subject.instrument_klass(Salutation, application_level: false)
        
        assert_equal true, Salutation.ancestors.include?(SalutationSpan)
        assert_match /instrument.rb/, Salutation.instance_method(:hello).source_location.first

        @trace.expects(:create_call_entry)
        @trace.expects(:create_call_return)

        Salutation.new.hello('Jim')
      end

      def test_application_level_instrumentation
        assert_equal false, Object.const_defined?(:ApplicationControllerSpan)

        @subject.instrument_klass(::ApplicationController, application_level: true)

        assert_equal true, Object.const_defined?(:ApplicationControllerSpan)
        assert_equal true, ::ApplicationController.ancestors.include?(::ApplicationControllerSpan)
        assert_equal true, ::ApplicationController.instance_methods.include?(:index)
        assert_equal true, ::ApplicationControllerSpan.instance_methods.include?(:index)
        assert_equal false, ::ApplicationControllerSpan.instance_methods.include?(:run_callbacks)

        @subject.instrument_klass(::ApplicationController, application_level: false)
        assert_equal true, ::ApplicationController.instance_methods.include?(:run_callbacks)
        assert_equal true, ::ApplicationControllerSpan.instance_methods.include?(:run_callbacks)
      end
    end
  end
end
