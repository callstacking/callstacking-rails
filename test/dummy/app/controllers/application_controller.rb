class ApplicationController < ActionController::Base
  include Callstacking::Rails::Helpers::InstrumentHelper

  before_action :include_settings

  prepend_around_action :callstacking_setup, if: -> { params[:debug] == '1' }

  def index
    @salutation = 'Hello from index'
  end

  def hello
    @salutation = 'Hello from hello'

    10.times do
      English.new.hello
      sleep_rand
    end

    render :index
  end

  def bounjor
    @salutation = 'Bounjour de bounjour'

    10.times do
      French.new.bounjor
      sleep_rand
    end

    render :index
  end

  def hallo
    @salutation = 'Hallo von hallo'

    10.times do
      German.new.hallo
      sleep_rand
    end

    render :index
  end

  private
  def include_settings
    @settings = Callstacking::Rails::Settings.new
    @settings.url
  end

  def sleep_rand
    sleep rand(0.0..2.0)
  end
end
