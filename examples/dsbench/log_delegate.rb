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

  def initialize(originalDelegate)
    @originalDelegate = originalDelegate
    @logs = nil
    @enable = true
  end

  def collect_logs
    raise "nested collect_logs call." if @logs
    @logs = []
    yield
    logs = @logs
    @logs = nil
    logs
  end
  attr_accessor :enable

  #public byte[] makeSyncCall(Environment env, String service, String method, byte[] requestBuf) throws ApiProxyException
  def makeSyncCall(env, service, method, requestBuf)
    unless @enable
      return @originalDelegate.makeSyncCall(env, service, method, requestBuf);
    end

    @qs ||= com.google.appengine.api.quota.QuotaServiceFactory.getQuotaService

    start_api_cycles = @qs.getApiTimeInMegaCycles
    start_ns = java.lang.System.nanoTime
    result = @originalDelegate.makeSyncCall(env, service, method, requestBuf);
    real_ms = (java.lang.System.nanoTime - start_ns)/1000000.0
    api_mega_cycles = @qs.getApiTimeInMegaCycles - start_api_cycles
    api_ms = @qs.convertMegacyclesToCpuSeconds(api_mega_cycles)*1000

    if @logs
      @logs << {:method=>"makeSyncCall/#{service}/#{method}", :req_size=>requestBuf.length, :resp_size=>result.length, :real_ms=>real_ms, :api_ms=>api_ms}
    end
    s = "$$$$ makeSyncCall/%12s/%16s | req=%6d | resp=%6d | api_ms=%8.2f real_ms=%8.2f" % [service, method, requestBuf.length, result.length, api_ms, real_ms]
    #s += " api_mega_cycles=#{api_mega_cycles}"
    if $env=="production"
      $app_logger.debug(s)
    elsif $env=="development"
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
