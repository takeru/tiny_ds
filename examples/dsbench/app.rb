require 'sinatra'
require 'tiny_ds'
require 'json'
require 'yaml'
require 'appengine-apis/memcache'
require 'appengine-apis/logger'

$gae_guid = "GAE"+Time.now.strftime("%Y%m%d%H%M%S")+"-"+java.util.UUID.randomUUID().to_s
$logger = AppEngine::Logger.new
def _log(s)
  $logger.info "#{Time.now.strftime('%Y%m%d_%H%M%S_%Z')},#{$gae_instance_guid},#{s}"
end

# Make sure our template can use <%=h
helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

require "log_delegate"
LogDelegate.install

class ManyPropertyKind
  def self.kind_name(count, type, index)
    name = "ManyProperty#{count}_#{type}"
    unless index
      name += "_NoIndex"
    end
    name
  end
  def self.define_class(count, type, index)
    name = kind_name(count, type, index)
    s = ""
    s << "class #{name} < TinyDS::Base\n"
    count.times do |i|
      s << "  property :prop_#{type}_#{i}, :#{type}, :index=>#{index}\n"
    end
    s << "end"
    eval(s, TOPLEVEL_BINDING)
  end
end

[1,2,4,8,16,32,64,128].each do |n|
  ManyPropertyKind.define_class(n, :integer, true)
  ManyPropertyKind.define_class(n, :integer, false)
  ManyPropertyKind.define_class(n, :string,  true)
  ManyPropertyKind.define_class(n, :string,  false)
end

get '/' do
  paths = []
  paths << "/01props_put?count=8&type=integer&index=true&repeat=10"
  paths << "/01props_put?count=32&type=integer&index=true&repeat=10"
  paths << "/01props_put?count=8&type=integer&index=false&repeat=10"
  paths << "/01props_put?count=32&type=integer&index=false&repeat=10"
  paths.collect{|path| "<a href='#{path}'>#{h(path)}</a><br />" }.join
end

# [01props] count of property, indexed or not
get '/01props_put' do
  count  = params[:count].to_i     # 1,2,4,8,16,32,64,128
  type   = params[:type].to_sym    # integer/string
  index  = params[:index]=="true"  # true/false
  repeat = params[:repeat].to_i    # 

  klass_name = ManyPropertyKind.kind_name(count, type, index)
  klass = eval(klass_name)

  bench_result = nil
  api_calls = LogDelegate.instance.collect_logs do
    bench_result = ds_benchmark do
      repeat.times do |repeat_count|
        e = klass.new
        count.times do |i|
          e.send("prop_#{type}_#{i}=", rand(10000))
        end
        e.save
      end
    end
  end

  pars = {:count=>count, :type=>type, :index=>index, :repeat=>repeat}
  api_calls_sum = {:real_ms=>api_calls.inject(0){|sum,a| sum+=a[:real_ms] }}
  content_type "text/plain"
  {:pars          => pars,
   :bench_result  => bench_result,
   :api_calls_sum => api_calls_sum,
   :api_calls     => api_calls,
   :now           => Time.now.strftime("%Y%m%d_%H%M%S_%Z"),
   :gae_guid      => $gae_guid}.to_yaml
end

$qs = com.google.appengine.api.quota.QuotaServiceFactory.getQuotaService
def ds_benchmark
  start_api_cycles = $qs.getApiTimeInMegaCycles
  start_ns = java.lang.System.nanoTime
  yield
  real_ms = (java.lang.System.nanoTime - start_ns)/1000000.0
  api_ms = $qs.convertMegacyclesToCpuSeconds( $qs.getApiTimeInMegaCycles - start_api_cycles )*1000
  # TODO cpu_ms
  {:api_ms=>api_ms, :real_ms=>real_ms}
end

def __current_quotas
  qs = com.google.appengine.api.quota.QuotaServiceFactory.getQuotaService
  cpu_cycles   = qs.getCpuTimeInMegaCycles
  cpu_sec      = qs.convertMegacyclesToCpuSeconds(cpu_cycles)
  cpu_supports = qs.supports(com.google.appengine.api.quota.QuotaService::DataType::CPU_TIME_IN_MEGACYCLES)
  api_cycles   = qs.getApiTimeInMegaCycles
  api_sec      = qs.convertMegacyclesToCpuSeconds(api_cycles)
  api_supports = qs.supports(com.google.appengine.api.quota.QuotaService::DataType::API_TIME_IN_MEGACYCLES)
  return {:cpu=>{:cycles=>cpu_cycles, :sec=>cpu_sec, :supports=>cpu_supports},
          :api=>{:cycles=>api_cycles, :sec=>api_sec, :supports=>api_supports}}
end


=begin
$mc     = AppEngine::Memcache.new
$mc.delete(counter_name)
count = $mc.incr(counter_name)
$mc.set(counter_name, count)
prev_t = $mc.get("global_timestamp")
# appcfg.rb --severity=0 request_logs . gae.log
# cat gae.log | ruby -e 'STDIN.each_char{|c| print(c=="\000" ? "\n" : c) }' | grep GAE | less
=end
