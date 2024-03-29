# frozen_string_literal: true

require 'minitest/autorun'

module Callstacking
  module Rails
    class CliTest < Minitest::Test

      def setup
        @settings = Callstacking::Rails::Settings.new
        Callstacking::Rails::Setup.any_instance.stubs(:start).returns(true)
      end
      
      def test_register
        @subject = Callstacking::Rails::Cli.new(Callstacking::Rails::Cli::REGISTER, @settings)
        assert_equal @subject.run, Callstacking::Rails::Cli::REGISTER
      end

      def test_setup
        @subject = Callstacking::Rails::Cli.new(Callstacking::Rails::Cli::SETUP, @settings)
        assert_equal @subject.run, Callstacking::Rails::Cli::SETUP
      end

      def test_enable
        @subject = Callstacking::Rails::Cli.new(Callstacking::Rails::Cli::ENABLE, @settings)
        assert_equal @subject.run, Callstacking::Rails::Cli::ENABLE
      end
      
      def test_disable
        @subject = Callstacking::Rails::Cli.new(Callstacking::Rails::Cli::DISABLE, @settings)
        assert_equal @subject.run, Callstacking::Rails::Cli::DISABLE
      end
    end
  end
end
