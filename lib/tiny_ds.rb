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
  def self.tx(retries=0, &block)
    AppEngine::Datastore.transaction(retries){
      yield(block)
    }
  end
end
