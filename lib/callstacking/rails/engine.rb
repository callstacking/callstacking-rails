require "rails"
require "callstacking/rails/traceable"
require "callstacking/rails/setup"
require "callstacking/rails/settings"
require "callstacking/rails/client/base"
require "callstacking/rails/client/authenticate"
require "callstacking/rails/client/trace"
require "callstacking/rails/traces_helper"

module Callstacking
  module Rails
    class Engine < ::Rails::Engine
      isolate_namespace Callstacking::Rails
      include ::Callstacking::Rails::Traceable

      initializer "engine_name.assets.precompile" do |app|
        app.config.assets.precompile << "checkpoint_rails_manifest.js"
      end

      initializer 'local_helper.action_controller' do
        ActiveSupport.on_load :action_controller do
          helper Callstacking::Rails::TracesHelper
          include Callstacking::Rails::TracesHelper
        end
      end

      initializer :append_before_action do
        ActionController::Base.send :after_action, :inject_hud
      end

      set_trace
    end
  end
end
