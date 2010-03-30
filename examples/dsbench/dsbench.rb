# ex. ruby -r dsbench.rb -e run_01props_put > 01props_put_`ts`.ymls

require "open-uri"
require "thread"
require "pp"
require "yaml"

config_ru = File.read("config.ru")
app_id      = config_ru[/:application\s*=>\s*[\'\"](.+)[\'\"]/, 1]
app_version = config_ru[/:version\s*=>\s*[\'\"](.+)[\'\"]/, 1]
$url_base = "http://#{app_version}.latest.#{app_id}.appspot.com"

$log_mutex = Mutex.new
def sync_puts(s)
  $log_mutex.synchronize{
    puts(s)
  }
end

def do_run_00warmup(thread_count, sleep_sec, loop_count)
  progress = 0
  increment_progress = proc{|s|
    $log_mutex.synchronize{
      progress += 1
      $stderr.puts("warmup [%d/%d] %s" % [progress, thread_count*loop_count, s])
    }
  }
  threads = []
  thread_count.times do |n|
    t = Thread.new(n) do |thread_no|
      loop_count.times do |loop_no|
        s = StringIO.new
        url = $url_base + "/00warmup?sleep_sec=#{sleep_sec}&_thread_no=#{thread_no}&_loop_no=#{loop_no}"
        begin
          open(url) do |f|
            s.puts f.read
          end
        rescue => e
          s.puts e.inspect
        end
        increment_progress.call(s.string)
      end
    end
    threads << t
  end
  threads.each do |t|
    t.join
  end
  nil
end

def run_01props_put_for_api_ms
  do_run_01props_put(
    :count => [1,2,4,8,16,32,64,128],
    :index => [true, false],
    :type  => ["integer", "string"],
    :txn   => [false],
    :batch => [false],
    :repeat => 5,
    :thread_count => 5
  )
end

# ruby -r dsbench.rb -e run_01props_put_for_txn_batch > 01props_put_for_txn_batch_`ts`.ymls
def run_01props_put_for_txn_batch
  do_run_00warmup(20, 0.5, 10)
  do_run_01props_put(
    :count  => [8],
    :index  => [true],
    :type   => ["integer"],
    :txn    => [true, false],
    :batch  => [true, false],
    :repeat => [1,4,8,32],
    :thread_count => 10
  )
end

def do_run_01props_put(arg)
  thread_count = arg[:thread_count]

  threads = []
  thread_count.times do
    t = Thread.new do
      arg[:count].each do |count|
        arg[:index].each do |index|
          arg[:type].each do |type|
            arg[:txn].each do |txn|
              arg[:batch].each do |batch|
                arg[:repeat].each do |repeat|
                  s = StringIO.new
                  url = $url_base + "/01props_put?count=#{count}&type=#{type}&index=#{index}&repeat=#{repeat}&txn=#{txn}&batch=#{batch}"
                  begin
                    open(url) do |f|
                      s.puts "######## count=#{count} type=#{type} index=#{index} repeat=#{repeat} txn=#{txn} batch=#{batch}"
                      s.puts f.read
                    end
                  rescue OpenURI::HTTPError => e
                    $stderr.puts("#{e.inspect} #{url}")
                    retry
                  end
                  sync_puts s.string
                end
              end
            end
          end
        end
      end
    end
    threads << t
  end
  threads.each do |t|
    t.join
  end
end

# ruby -r dsbench.rb -e parse_01props_put < 01props_put_20100130_175803.ymls | sort
def parse_01props_put_for_api_ms
  raise
  $stdin.read.split(/^########.+$/).each do |s|
    result = YAML.load(s)
    next unless result
    count  = result[:pars][:count]
    type   = result[:pars][:type]
    index  = result[:pars][:index]
    repeat = result[:pars][:repeat]
    api_ms_per_call  = result[:bench_result][:api_ms] / result[:api_calls].size
    real_ms_per_call = result[:api_calls].inject(0){|sum,a| sum+=a[:real_ms] } / result[:api_calls].size
    key = "#{'%03d' % count}_#{type.to_s[0,1]}_#{index.to_s[0,1]}_#{'%02d' % repeat}"
    puts "#{key},#{'%10.2f' % api_ms_per_call},#{'%10.2f' % real_ms_per_call}"
  end
end

# ruby -r dsbench.rb -e parse_01props_put_for_txn_batch < 01props_put_for_txn_batch_20100330_164516.ymls | sort
def parse_01props_put_for_txn_batch
  $stdin.read.split(/^########.+$/).each do |s|
    result = YAML.load(s)
    next unless result
    count  = result[:pars][:count]
    type   = result[:pars][:type]
    index  = result[:pars][:index]
    repeat = result[:pars][:repeat]
    txn    = result[:pars][:txn]
    batch  = result[:pars][:batch]

    api_ms_per_entity  = result[:bench_result][:rpc_calls_sum][:api_ms]  / repeat
    cpu_ms_per_entity  = result[:bench_result][:rpc_calls_sum][:cpu_ms]  / repeat
    real_ms_per_entity = result[:bench_result][:rpc_calls_sum][:real_ms] / repeat

    key = "#{'%03d' % count}_#{type.to_s[0,1]}_#{index ? 'I' : 'i'}_#{'%02d' % repeat}_#{txn ? 'T' : 't'}_#{batch ? 'B' : 'b'}"
    puts "#{key},#{'%10.2f' % api_ms_per_entity},#{'%10.2f' % cpu_ms_per_entity},#{'%10.2f' % real_ms_per_entity}"
  end
end



#########################################################################################
def run_11pbsize_put
  threads = []
  10.times do
    t = Thread.new do
      [     1,
         1000,  2000,  4000,  8000,
        10000, 20000, 40000, 80000,
       100000,200000,400000,800000 ].each do |size|
        s = StringIO.new
        repeat = 5
        url = $url_base + "/11pbsize_put?size=#{size}&repeat=#{repeat}"
        open(url) do |f|
          s.puts "######## size=#{size} repeat=#{repeat}"
          s.puts f.read
        end
        sync_puts s.string
        sleep(3*size/100000)
      end
    end
    threads << t
  end
  threads.each do |t|
    t.join
  end
end

# ruby -r dsbench.rb -e parse_11pbsize_put < 11pbsize_put_20100130_202301.ymls | sort
def parse_11pbsize_put
  raise

  $stdin.read.split(/^########.+$/).each do |s|
    result = YAML.load(s)
    next unless result
    size   = result[:pars][:size]
    repeat = result[:pars][:repeat]
    api_ms_per_call  = result[:bench_result][:api_ms] / result[:api_calls].size
    real_ms_per_call = result[:api_calls].inject(0){|sum,a| sum+=a[:real_ms] } / result[:api_calls].size
    key = "#{'%06d' % size}_#{'%02d' % repeat}"
    puts "#{key},#{'%10.2f' % api_ms_per_call},#{'%10.2f' % real_ms_per_call}"
  end
end

#########################################################################################
def run_21list_put
  threads = []
  10.times do
    t = Thread.new do
      [0,1,2,4,8,16,32,64,128,256].each do |size|
        [true,false].each do |index|
          s = StringIO.new
          repeat = 5
          url = $url_base + "/21list_put?size=#{size}&index=#{index}&repeat=#{repeat}"
          open(url) do |f|
            s.puts "######## size=#{size} index=#{index} repeat=#{repeat}"
            s.puts f.read
          end
          sync_puts s.string
          sleep(size/100)
        end
      end
    end
    threads << t
  end
  threads.each do |t|
    t.join
  end
end

# ruby -r dsbench.rb -e parse_21list_put < 
def parse_21list_put
  raise

  $stdin.read.split(/^########.+$/).each do |s|
    result = YAML.load(s)
    next unless result
    size   = result[:pars][:size]
    index  = result[:pars][:index]
    repeat = result[:pars][:repeat]
    api_ms_per_call  = result[:bench_result][:api_ms] / result[:api_calls].size
    real_ms_per_call = result[:api_calls].inject(0){|sum,a| sum+=a[:real_ms] } / result[:api_calls].size
    key = "#{'%06d' % size}_#{index.to_s[0,1]}_#{'%02d' % repeat}"
    puts "#{key},#{'%10.2f' % api_ms_per_call},#{'%10.2f' % real_ms_per_call}"
  end
end

