# frozen_string_literal: true

require 'minitest/autorun'

module Callstacking
  module Rails
    class ExeTest < Minitest::Test
      def test_register
        test_run('./exe/callstacking-rails register')
      end

      def test_setup
        # test_run('./exe/callstacking-rails setup')
      end

      def test_enable
        test_run('./exe/callstacking-rails enable')
      end

      def test_disable
        test_run('./exe/callstacking-rails disable')
      end

      private
      def test_run(command)
        refute_match /Error/, `#{command}`
      end
    end
  end
end
