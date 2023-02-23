# frozen_string_literal: true

require 'minitest/autorun'
require 'callstacking/rails/setup'

module Callstacking
  module Rails
    class SetupTest < Minitest::Test
      def setup
        @subject = Callstacking::Rails::Setup.new
      end

      def test_start
        def @subject.prompt(*_args)
          'test-value'
        end

        def @subject.token(*_args)
          'auth-token'
        end

        assert_equal true, @subject.start
      end
    end
  end
end
