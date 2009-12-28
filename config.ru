require 'appengine-rack'
AppEngine::Rack.configure_app(
    :application => 'your-app-id',
    :precompilation_enabled => true,
    :version => "tinyds")
require "app"
run Sinatra::Application
