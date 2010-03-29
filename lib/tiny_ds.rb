require 'appengine-apis'
require 'appengine-apis/datastore'
require File.dirname(__FILE__)+"/tiny_ds/low_ds.rb"
require File.dirname(__FILE__)+"/tiny_ds/property_definition.rb"
require File.dirname(__FILE__)+"/tiny_ds/base.rb"
require File.dirname(__FILE__)+"/tiny_ds/query.rb"
require File.dirname(__FILE__)+"/tiny_ds/validations.rb"
require File.dirname(__FILE__)+"/tiny_ds/transaction.rb"
#require File.dirname(__FILE__)+"/tiny_ds/base_tx.rb"
require File.dirname(__FILE__)+"/tiny_ds/base_tx2.rb"
require File.dirname(__FILE__)+"/tiny_ds/version.rb"

module TinyDS
  # execute block in new transaction.
  # if current_transaction is exists, no new tx is begin.
  # if force_begin=true, always begin new tx.
  def self.tx(opts={})
    retries = opts[:retries] || 0
    cur_tx = nil
    unless opts[:force_begin]
      cur_tx = AppEngine::Datastore.current_transaction(nil)
    end
    if cur_tx
      yield
    else
#      begin
        AppEngine::Datastore.transaction(retries){
          yield
        }
#      rescue NativeException => e
# $app_logger.info "TinyDS.tx NativeException e.cause.class=#{e.cause.class}"
# # http://tinymsg.appspot.com/pLT
#        raise e
#      end
    end
  end
  def self.readonly
    raise "todo"
  end
  def batch_get
    raise "todo"
  end
  def self.batch_put(objs)
    AppEngine::Datastore.put(objs.collect{|o| o.entity })
  end
  def self.batch_save(objs)
    # TODO other before hooks...
    objs.each do |o|
      o.__before_save_set_timestamps
    end
    batch_put(objs)
  end
end
