# frozen_string_literal: true

require 'minitest/autorun'

module Callstacking
  module Rails
    class InstrumentTest < Minitest::Test
      def setup
        @spans = Callstacking::Rails::Spans.new
        @subject = Callstacking::Rails::Instrument.new(@spans, Salutation)
      end

      def test_instrument_klass
        assert_match /app\/models\/salutation\.rb/, Salutation.instance_method(:hello).source_location.first

        @subject.instrument_klass(application_level: false)

        assert_equal true, Salutation.ancestors.include?(SalutationSpan)
        assert_match /instrument.rb/, Salutation.instance_method(:hello).source_location.first
      end
    end
  end
end
