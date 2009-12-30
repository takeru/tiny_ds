require 'appengine-rack'
AppEngine::Rack.configure_app(
    :application => 'your-app-id',
    :precompilation_enabled => true,
    :version => "tinyds")

require "app"

configure :development do
  class Sinatra::Reloader < ::Rack::Reloader
    def safe_load(file, mtime, stderr = $stderr)
      ::Sinatra::Application.reset!
      super
    end
  end
  use Sinatra::Reloader
end

run Sinatra::Application
