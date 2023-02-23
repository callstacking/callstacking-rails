# frozen_string_literal: true

require 'minitest/autorun'

module Callstacking
  module Rails
    class InstrumentTest < Minitest::Test
      class Salutation
        def hello(name)
          "hello #{name}"
        end

        def self.hello(name)
          "hi #{name}"
        end

        def hi(first_name, last_name:)
          "hi #{first_name} #{last_name}"
        end

        def self.hi(first_name:, last_name:)
          "hi #{first_name} #{last_name}"
        end
      end
      
      def setup
        @spans = Callstacking::Rails::Spans.new
        @subject = Callstacking::Rails::Instrument.new(@spans, Salutation)
      end

      def test_instrument_klass
        @subject.instrument_klass(application_level: false)
        assert_equal true, Salutation.ancestors.include?(CallstackingRailsInstrumentTestSalutationSpan)
      end
    end
  end
end
