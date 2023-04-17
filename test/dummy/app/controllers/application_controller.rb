class ApplicationController < ActionController::Base
  include Callstacking::Rails::Helpers::InstrumentHelper

  around_action :callstacking_setup, if: -> { params[:debug] == '1' }

  def index
    @settings = Callstacking::Rails::Settings.new
  end
end
