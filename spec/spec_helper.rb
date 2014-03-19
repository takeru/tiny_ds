require "pp"
$:.push File.join(File.dirname(__FILE__), '..', 'lib')
begin
  require 'rubygems'
  require "java"
  require 'rspec'
  require 'rspec/unit'
  Dir["#{File.dirname(__FILE__)}/helpers/*.rb"].each do |file|
    require file
  end
  require 'appengine-apis'
  require 'appengine-api-1.0-sdk-1.4.0.jar'
  if false
    puts "======="
    puts "$LOAD_PATH"
    pp $LOAD_PATH
    puts "======="
    puts "java.class.path"
    pp java.lang.System.getProperty("java.class.path").split(":")
    puts "======="
=begin
% appcfg.rb run -rpp -e 'pp java.lang.System.getProperty("java.class.path").split(":")'
[".../tiny_ds/WEB-INF/lib/appengine-api-1.0-sdk-1.3.0.jar",
 ".../tiny_ds/WEB-INF/lib/appengine-api-labs-1.3.0.jar",
 ".../tiny_ds/WEB-INF/lib/appengine-jruby-0.0.6.jar",
 ".../tiny_ds/WEB-INF/lib/gems.jar",
 ".../tiny_ds/WEB-INF/lib/jruby-rack-0.9.6-SNAPSHOT.jar",
 "/opt/local/lib/ruby/gems/1.8/gems/appengine-sdk-1.3.0/appengine-java-sdk-1.3.0/lib/shared/appengine-local-runtime-shared.jar",
 "/opt/local/lib/ruby/gems/1.8/gems/appengine-sdk-1.3.0/appengine-java-sdk-1.3.0/lib/impl/appengine-api-stubs.jar",
 "/opt/local/lib/ruby/gems/1.8/gems/appengine-sdk-1.3.0/appengine-java-sdk-1.3.0/lib/impl/appengine-local-runtime.jar"]

% source set_classpath_for_jruby.sh

% jruby -rjava -rpp -e 'pp java.lang.System.getProperty("java.class.path").split(":")'
["/Users/takeru/tmp/jruby-1.4.0/lib/jruby.jar",
 "/Users/takeru/tmp/jruby-1.4.0/lib/profile.jar",
 "",
 ".../tiny_ds/WEB-INF/lib/appengine-api-1.0-sdk-1.3.0.jar",
 ".../tiny_ds/WEB-INF/lib/appengine-api-labs-1.3.0.jar",
 "/opt/local/lib/ruby/gems/1.8/gems/appengine-sdk-1.3.0/appengine-java-sdk-1.3.0/lib/shared/appengine-local-runtime-shared.jar",
 "/opt/local/lib/ruby/gems/1.8/gems/appengine-sdk-1.3.0/appengine-java-sdk-1.3.0/lib/impl/appengine-api-stubs.jar",
 "/opt/local/lib/ruby/gems/1.8/gems/appengine-sdk-1.3.0/appengine-java-sdk-1.3.0/lib/impl/appengine-local-runtime.jar"]
=end
  end

  require 'rubygems'
  require "logger"
  # require 'appengine-sdk'
  # AppEngine::SDK.load_apiproxy
  require "tiny_ds"
  require 'appengine-apis/testing'
  if true 
    # 1.3.2
    AppEngine::Testing.setup
  else
    # 1.3.0
    begin
      AppEngine::ApiProxy.get_app_id
    rescue NoMethodError
      AppEngine::Testing::install_test_env
    end
  end
  at_exit do
    $stdout.flush
    $stderr.flush
    sleep 1
    java.lang.System.exit(0)
  end
  AppEngine::Testing::install_test_datastore
  $app_logger = Logger.new($stderr)
rescue Object => e
  puts e.inspect
  pp e.backtrace
  raise e
end
