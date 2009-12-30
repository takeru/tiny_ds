require 'sinatra'
require 'lib/tiny_ds'
require 'appengine-apis/memcache'
require 'appengine-apis/logger'

$gae_instance_guid = "GAE"+Time.now.strftime("%Y%m%d%H%M%S")+"-"+java.util.UUID.randomUUID().to_s

# Create your model class
class Shout < TinyDS::Base
  property :message,    :text
  property :created_at, :time
  property :updated_at, :time
end

# Make sure our template can use <%=h
helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

get '/' do
  # Just list all the shouts
  @shouts = Shout.query.sort(:created_at, :desc).all
  erb :index
end

post '/' do
  # Create a new shout and redirect back to the list.
  shout = Shout.create(:message => params[:message])
  redirect '/'
end

get '/show/:id' do
  @shout = Shout.get_by_id(params[:id])
  erb :show
end

# [LogCounter]
# http://d.hatena.ne.jp/kazunori_279/20091229/1262063435
$mc     = AppEngine::Memcache.new
$logger = AppEngine::Logger.new
class CountLog < TinyDS::Base
  property :counter_name, :string
  property :value,        :integer
  property :created_ms,   :integer
end
get "/count_log/:counter_name" do
  counter_name = params[:counter_name]
  # log("rand = #{rand(100)}")
  # simulate memcache expire.
  if rand(10)==0
    $mc.delete(counter_name)
    log("reset_memcache,#{counter_name}")
  end
  if rand(10)==0
    $mc.delete("global_timestamp")
    log("reset_memcache,global_timestamp")
  end

  count = countup(counter_name)
  s = "countup,#{counter_name},#{count}"
  log(s)
  s
end
def countup(counter_name)
  count = $mc.incr(counter_name)
  if count.nil?
    cl = CountLog.query.filter(:counter_name, "==", counter_name).sort(:created_ms, :desc).all(:limit=>1).first
    count = cl.nil? ? 0 : cl.value
    $mc.set(counter_name, count)
    log("counter_loaded,#{counter_name},#{count}")
    return countup(counter_name)
  end
  CountLog.create!(:counter_name=>counter_name, :value=>count, :created_ms=>global_timestamp)
  count
end
def global_timestamp
  current_t = java.lang.System.currentTimeMillis
  prev_t    = $mc.get("global_timestamp") || 0
  t = [current_t, prev_t+1].max
  $mc.set("global_timestamp", t)
  t
end
def log(s)
  s << ",#{Time.now.strftime('%Y%m%d_%H%M%S')},#{$gae_instance_guid}"
# $logger.warn s
  $logger.info s
end

# appcfg.rb --severity=0 request_logs . gae.log
# cat gae.log | ruby -e 'STDIN.each_char{|c| print(c=="\000" ? "\n" : c) }' | grep GAE | less

=begin
1:1262154133.985000 countup,test003,2066,20091230_062213,GAE20091230062125-c0dbddfc-49f2-4b09-a27c-f92e6c0a4e33
1:1262154133.958000 countup,test003,2066,20091230_062213,GAE20091230062203-8f154c6d-98c2-407c-91c3-e97fb486aca1

1:1262154130.162000 countup,test003,1994,20091230_062210,GAE20091230062106-ce3a4ee3-b055-459b-8a1d-44b0a9d7cf17
1:1262154130.085000 countup,test003,1994,20091230_062210,GAE20091230062203-8f154c6d-98c2-407c-91c3-e97fb486aca1

1:1262154126.210000 countup,test003,1935,20091230_062206,GAE20091230062114-22812006-49e7-4464-8dbe-c177d81236aa
1:1262154126.195000 countup,test003,1935,20091230_062206,GAE20091230062106-ce3a4ee3-b055-459b-8a1d-44b0a9d7cf17
1:1262154126.172000 countup,test003,1935,20091230_062206,GAE20091230062138-3c816a23-74d9-4fd8-b070-ec8b153c892d
=end
