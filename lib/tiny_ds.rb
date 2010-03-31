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

unless defined?(constantize)
  def constantize(camel_cased_word)
    unless /\A(?:::)?([A-Z]\w*(?:::[A-Z]\w*)*)\z/ =~ camel_cased_word
      raise NameError, "#{camel_cased_word.inspect} is not a valid constant name!"
    end
    Object.module_eval("::#{$1}", __FILE__, __LINE__)
  end
end

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

  # key_and_classes is like : [key, key, [key, User], [key, "User"]...]
  # default class is entity's kind.
  def self.batch_get(key_and_classes)
    _key_and_classes = key_and_classes.collect{|key,klass|
      key = TinyDS::Base.to_key(key)
      if klass.nil? || klass.kind_of?(String)
        klass ||= key.kind
        klass = constantize(klass)
      end
      [key, klass]
    }
    entities = LowDS.batch_get(_key_and_classes.collect{|key,klass| key })
    objs = []
    entities.zip(_key_and_classes) do |ent,(key,klass)|
      objs << if ent
                klass.new_from_entity(ent)
              else
                nil
              end
    end
    objs
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
