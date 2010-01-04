require 'sinatra'
require 'tiny_ds'
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
    global_synchronize("mutex_#{counter_name}") do
      break unless $mc.get(counter_name).nil? # other instance restored 'count'.
      cl = CountLog.query.filter(:counter_name=>counter_name).sort(:created_ms, :desc).all(:limit=>1).first
      count = cl.nil? ? 0 : cl.value
      $mc.set(counter_name, count)
      log("counter_loaded,#{counter_name},#{count}")
    end
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

# [memcache mutex]
# http://d.hatena.ne.jp/kazunori_279/20091005/1254707722
def global_synchronize(mutex_name, retries=10, sleep_sec=0.5)
  (1+retries).times{
    unless global_acquire_lock(mutex_name)
      sleep(sleep_sec)
      next
    end
    ret = nil
    begin
      ret = yield
    ensure
      global_release_lock(mutex_name)
    end
    return ret
  }
  raise "could not get lock!!"
end
def global_acquire_lock(mutex_name)
  count = $mc.incr(mutex_name)
  if count.nil?
    $mc.set(mutex_name, 0)
    return false
  end
  if count==1
    return true
  else
    $mc.decr(mutex_name)
    return false
  end
end
def global_release_lock(mutex_name)
  $mc.decr(mutex_name)
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



# [list_prop]
class Item < TinyDS::Base
  property :nickname,   :string
  property :nums,       :list
end
get "/list_props" do
  Item.destroy_all
  raise "Item.count==#{Item.count}" if Item.count != 0
  #Item.create(:nums=>[])
  cmds = <<END
Item.destroy_all
Item.create(:nickname=>"A", :nums=>[1,2,3]).inspect
Item.create(:nickname=>"B", :nums=>[]     ).inspect
Item.create(:nickname=>"C", :nums=>[nil]  ).inspect
Item.create(:nickname=>"D", :nums=>nil    ).inspect
Item.create(:nickname=>"E"                ).inspect
Item.query.all.collect{|i| i.nickname }.inspect
Item.count
Item.query.filter(:nums,"==",      0).collect{|i| i.nickname }.inspect
Item.query.filter(:nums,"<=",      0).collect{|i| i.nickname }.inspect
Item.query.filter(:nums,">=",      0).collect{|i| i.nickname }.inspect

Item.query.filter(:nums,"<",-(2**63)).collect{|i| i.nickname }.inspect
Item.query.filter(:nickname=>"B").one.entity[:nums].inspect
Item.query.filter(:nickname=>"B").one.entity.has_property(:nums)
Item.query.filter(:nickname=>"C").one.entity[:nums].inspect
Item.query.filter(:nickname=>"C").one.entity[:nums].to_a.inspect
Item.query.filter(:nickname=>"C").one.entity.has_property(:nums)
Item.query.filter(:nickname=>"D").one.entity[:nums].inspect
Item.query.filter(:nickname=>"D").one.entity.has_property(:nums)
Item.query.filter(:nickname=>"E").one.entity[:nums].inspect
Item.query.filter(:nickname=>"E").one.entity.has_property(:nums)
END
  return "<table border=1>" +
    cmds.collect{|cmd|
      "<tr><td>#{h(cmd)}</td><td>#{h(eval(cmd))}</td></tr>"
    }.join +
    "</table>"
end
