require 'appengine-apis'
require 'appengine-apis/datastore'
require File.dirname(__FILE__)+"/tiny_ds/low_ds.rb"
require File.dirname(__FILE__)+"/tiny_ds/property_definition.rb"
require File.dirname(__FILE__)+"/tiny_ds/base.rb"
require File.dirname(__FILE__)+"/tiny_ds/query.rb"
require File.dirname(__FILE__)+"/tiny_ds/validations.rb"
require File.dirname(__FILE__)+"/tiny_ds/transaction.rb"
require File.dirname(__FILE__)+"/tiny_ds/base_tx.rb"
require File.dirname(__FILE__)+"/tiny_ds/version.rb"

module TinyDS
  # execute block in new transaction.
  # if current_transaction is exists, no new tx is begin.
  # if force_begin=true, always begin new tx.
  def self.tx(opts={}, &block)
    retries = opts[:retries] || 0
    cur_tx = nil
    unless opts[:force_begin]
      cur_tx = AppEngine::Datastore.current_transaction(nil)
    end
    if cur_tx
      yield(block)
    else
      AppEngine::Datastore.transaction(retries){
        yield(block)
      }
    end
  end
  def self.readonly(&block)
    raise "todo"
  end
  def batch_get
    raise "todo"
  end
  def batch_put
    raise "todo"
  end
end
