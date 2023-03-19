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
    end
  end
end
