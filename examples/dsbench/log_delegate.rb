require 'term/ansicolor'
class LogDelegate #implements Delegate<Environment>
  include Term::ANSIColor

  def self.instance
    unless @instance
      @instance = new(AppEngine::ApiProxy.getDelegate())
      AppEngine::ApiProxy.setDelegate(@instance)
    end
    @instance
  end
  def self.install
    instance
  end
  def self.collect_logs(&block)
    instance.collect_logs(&block)
  end
  def self.enable=(v)
    instance.enable = v
  end
  def self.environment=(v)
    instance.environment = v
  end
  def self.logger=(v)
    instance.logger = v
  end

  def initialize(originalDelegate)
    @originalDelegate = originalDelegate
    @logs = nil
    @enable = true
    @environment = "development"
    @logger = Logger.new($stderr)
  end

  def collect_logs
    raise "nested collect_logs call." if @logs
    logs = nil
    begin
      @logs = []
      yield
      logs = @logs
    ensure
      @logs = nil
    end
    logs
  end
  attr_accessor :enable
  attr_accessor :environment
  attr_accessor :logger

  #public byte[] makeSyncCall(Environment env, String service, String method, byte[] requestBuf) throws ApiProxyException
  def makeSyncCall(env, service, method, requestBuf)
    unless @enable
      return @originalDelegate.makeSyncCall(env, service, method, requestBuf);
    end

    @qs ||= com.google.appengine.api.quota.QuotaServiceFactory.getQuotaService

    begin_api_cycles = @qs.getApiTimeInMegaCycles
    begin_cpu_cycles = @qs.getCpuTimeInMegaCycles
    begin_ns         = java.lang.System.nanoTime
    result           = @originalDelegate.makeSyncCall(env, service, method, requestBuf);
    end_ns           = java.lang.System.nanoTime
    end_cpu_cycles   = @qs.getCpuTimeInMegaCycles
    end_api_cycles   = @qs.getApiTimeInMegaCycles

    api_ms  = @qs.convertMegacyclesToCpuSeconds(end_api_cycles - begin_api_cycles)*1000
    cpu_ms  = @qs.convertMegacyclesToCpuSeconds(end_cpu_cycles - begin_cpu_cycles)/1000.0
    real_ms = (end_ns - begin_ns)/1000000.0

    if @logs
      @logs << {:method=>"makeSyncCall/#{service}/#{method}",
                :req_size=>requestBuf.length,
                :resp_size=>result.length,
                :api_ms=>api_ms,
                :cpu_ms=>cpu_ms,
                :real_ms=>real_ms }
    end
    s = "$$$$ makeSyncCall/%12s/%16s | req=%6d | resp=%6d | api_ms=%8.2f cpu_ms=%8.2f real_ms=%8.2f" % [service, method, requestBuf.length, result.length, api_ms, cpu_ms, real_ms]
    if @environment=="production"
      @logger.debug(s)
    elsif @environment=="development"
      print red, on_white, bold, s, reset, "\n"
    end
    result
  end

  #public Future<byte[]> makeAsyncCall(Environment env, String service, String method, byte[] requestBuf, ApiConfig config)
  def makeAsyncCall(env, service, method, requestBuf, config)
    #puts "makeAsyncCall/#{service}/#{method} #{requestBuf.length}"
    @originalDelegate.makeAsyncCall(env, service, method, requestBuf, config)
  end

  #public void log(Environment env, LogRecord rec)
  def log(env,rec)
    #puts "log #{rec.inspect}"
    @originalDelegate.log(env, rec)
  end
end
