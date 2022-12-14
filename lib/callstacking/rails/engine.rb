require "rails"
require "callstacking/rails/trace"
require "callstacking/rails/instrument"
require 'callstacking/rails/spans'
require "callstacking/rails/setup"
require "callstacking/rails/settings"
require "callstacking/rails/loader"
require "callstacking/rails/client/base"
require "callstacking/rails/client/authenticate"
require "callstacking/rails/client/trace"
require "callstacking/rails/traces_helper"

module Callstacking
  module Rails
    class Engine < ::Rails::Engine
      include Settings
      isolate_namespace Callstacking::Rails

      read_settings

      spans = Spans.new
      trace = Trace.new(spans)

      initializer "engine_name.assets.precompile" do |app|
        app.config.assets.precompile << "checkpoint_rails_manifest.js"
      end

      initializer 'local_helper.action_controller' do
        ActiveSupport.on_load :action_controller do
          include Callstacking::Rails::TracesHelper
        end

        Callstacking::Rails::Loader.new.on_load(spans) if enabled?
      end

      initializer :append_before_action do
        ActionController::Base.send :after_action, :inject_hud
      end

      if enabled?
        puts "Callstacking enabled (#{Callstacking::Rails::Env.environment})"
        trace.tracing
      else
        puts "Callstacking disabled (#{Callstacking::Rails::Env.environment})"
      end
    end
  end
end
