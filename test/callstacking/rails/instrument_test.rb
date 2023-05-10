# frozen_string_literal: true

require "test_helper"
require 'minitest/autorun'
require 'active_support/dependencies.rb'

module Callstacking
  module Rails
    class InstrumentTest < Minitest::Test
      TEST_MODULES = [:SalutationSpan, :ApplicationControllerSpan]

      def setup
        @spans   = Callstacking::Rails::Spans.new
        @trace   = Callstacking::Rails::Trace.new(@spans)
        @subject = Callstacking::Rails::Instrument.new(@spans)
        @settings = Callstacking::Rails::Settings.new

        # The tests run in random order.
        # The above TEST_MODULES may or may not be globally defined.
        # Need to reset them for each test.
        modules = TEST_MODULES.collect do |m|
          m.to_s.constantize if Object.const_defined?(m)
        end.compact

        @subject.disable!(modules)
        @settings.enable!
      end

      def test_instrument_klass
        assert_match /app\/models\/salutation\.rb/, Salutation.instance_method(:hello).source_location.first

        Trace.any_instance.expects(:create_call_entry).never
        Trace.any_instance.expects(:create_call_return).never

        Salutation.new.hello('Jim')

        @subject.instrument_klass(Salutation, application_level: true)

        assert_equal 2, ::SalutationSpan.instance_methods(false).size

        assert_equal true, Salutation.ancestors.include?(::SalutationSpan)
        assert_match /instrument.rb/, Salutation.instance_method(:hello).source_location.first

        Trace.any_instance.expects(:create_call_entry)
        Trace.any_instance.expects(:create_call_return)

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

      def test_enable_disable
        assert_equal false, module_and_method_exist?('SalutationSpan', :hello)

        @subject.enable!([Salutation])

        assert_equal true, Salutation.ancestors.include?(::SalutationSpan)
        assert_equal true, module_and_method_exist?('SalutationSpan', :hello)

        assert_match /instrument.rb/, Salutation.instance_method(:hello).source_location.first
        assert_equal 2, ::SalutationSpan.instance_methods(false).size

        @subject.disable!
        assert_equal true, Object.const_defined?(:SalutationSpan)
        assert_equal true, Salutation.ancestors.include?(::SalutationSpan)

        # assert_match /app\/models\/salutation\.rb/, Salutation.instance_method(:hello).source_location.first
        assert_equal 0, ::SalutationSpan.instance_methods.size
      end
    end
  end
end
