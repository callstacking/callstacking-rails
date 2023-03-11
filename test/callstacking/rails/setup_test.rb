# frozen_string_literal: true

require 'minitest/autorun'
require 'callstacking/rails/setup'

module Callstacking
  module Rails
    class SetupTest < Minitest::Test
      def setup
        @subject = Callstacking::Rails::Setup.new
        Callstacking::Rails::Settings.any_instance.stubs(:save).returns(true)
      end

      def test_start
        @subject.stubs(:prompt).returns('value')

        assert_equal true, @subject.start
      end
      def test_instructions
        assert_equal :instructions, Callstacking::Rails::Setup.instructions
      end
    end
  end
end
