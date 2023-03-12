class ApplicationController < ActionController::Base
  def index
    @settings = Callstacking::Rails::Settings.new
  end
end
