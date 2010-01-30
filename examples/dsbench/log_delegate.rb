#import java.util.concurrent.Future;
#import java.util.logging.Logger;
#import com.google.apphosting.api.ApiProxy;
#import com.google.apphosting.api.ApiProxy.ApiConfig;
#import com.google.apphosting.api.ApiProxy.ApiProxyException;
#import com.google.apphosting.api.ApiProxy.Delegate;
#import com.google.apphosting.api.ApiProxy.Environment;
#import com.google.apphosting.api.ApiProxy.LogRecord;

class LogDelegate
  #implements Delegate<Environment>
  def self.instance
    @instance
  end
  def self.install
    return false if @instance
    @instance = new(AppEngine::ApiProxy.getDelegate())
    AppEngine::ApiProxy.setDelegate(@instance)
    true
  end

  def initialize(originalDelegate)
    @originalDelegate = originalDelegate
    @logs = []
  end

  def reset
    prev_logs = @logs
    @logs = []
    prev_logs
  end

  def collect_logs
    reset
    yield
    reset
  end

  #public byte[] makeSyncCall(Environment env, String service, String method, byte[] requestBuf) throws ApiProxyException
  def makeSyncCall(env, service, method, requestBuf)
    #puts "makeSyncCall/#{service}/#{method} #{requestBuf.length}"
    start_ns = java.lang.System.nanoTime
    result = @originalDelegate.makeSyncCall(env, service, method, requestBuf);
    real_ms = (java.lang.System.nanoTime - start_ns)/1000000.0
    @logs << {:method=>"makeSyncCall/#{service}/#{method}", :requestBuf_length=>requestBuf.length, :real_ms=>real_ms}
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
