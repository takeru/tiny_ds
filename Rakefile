require 'rubygems'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'rubygems/specification'
require 'date'
require 'rspec/core/rake_task'

require File.dirname(__FILE__) + '/lib/tiny_ds/version'

# set up pretty rdoc if possible
begin
  gem 'rdoc'
  require 'sdoc'
  ENV['RDOCOPT'] = '-T lightblue'
rescue Exception
end

spec = Gem::Specification.new do |s|
  s.name = "tiny_ds"
  s.version = TinyDS::VERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.rdoc", "LICENSE"]
  s.description = "Tiny datastore library for Google App Engine with JRuby"
  s.summary = "Supports CRUD like a ActiveRecord or DataMapepr " +
              "but with parent/child and entity-group-transaction"
  s.author = "Takeru Sasaki"
  s.email = "sasaki.takeru@gmail.com"
  s.homepage = "http://github.com/takeru/tiny_ds"
  s.require_path = 'lib'
  s.files = %w(LICENSE README.rdoc Rakefile) +
            Dir.glob("spec/**/*.rb") + Dir.glob("lib/**/*.rb")
  s.add_dependency('appengine-apis')
end

task :default => :gem

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

Rake::RDocTask.new do |rd|
   rd.main = "README.rdoc"
   rd.rdoc_files.include("README.rdoc", "lib/**/*.rb")
end

RSpec::Core::RakeTask.new(:spec)
