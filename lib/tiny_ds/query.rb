module TinyDS
class Query
  def initialize(model_class)
    @model_class = model_class
    @q = AppEngine::Datastore::Query.new(@model_class.kind)
  end
  def ancestor(anc)
    anc = case anc
          when Base;   anc.key
          when String; LowDS::KeyFactory.stringToKey(anc)
          when AppEngine::Datastore::Key; anc
          else raise "unknown type. anc=#{anc.inspect}"
          end
    @q.set_ancestor(anc)
    self
  end
  def filter(*args)
    if args.size==1 && args.first.kind_of?(Hash)
      args.first.each do |k,v|
        filter(k,"==",v)
      end
    else
      name, operator, value = *args
      @model_class.property_definition(name) # check exist?
      @q.filter(name, operator, value)
    end
    self
  end
  def sort(name, dir=:asc)
    @model_class.property_definition(name) # check exist?
    direction = {
      :asc  => AppEngine::Datastore::Query::ASCENDING,
      :desc => AppEngine::Datastore::Query::DESCENDING
    }[dir]
    @q.sort(name, direction)
    self
  end
  def keys_only
    @q.java_query.setKeysOnly
    self
  end
  def count #todo(tx=nil)
    @q.count
  end
  def count2
    _count = 0
    max_key = nil
    loop do
      q = @q.clone # or ruby dup
      q.filter(:__key__, ">", max_key) if max_key
      q.sort(:__key__)
      q.java_query.setKeysOnly
      entries = q.fetch(:limit=>1000).to_a
      #p ["entries=", entries.collect{|e| e.key }]
      c = entries.size
      break if c==0
      _count += c
      max_key = entries.last.key
      #p ["max_key=", max_key]
    end
    _count
  end
  def one #todo(tx=nil)
    if @q.entity
      @model_class.new_from_entity(@q.entity)
    else
      nil
    end
  end
  def all(opts={}) #todo(tx=nil)
    models = []
    @q.each(opts) do |entity|
      models << @model_class.new_from_entity(entity)
    end
    models
  end
  def each(opts={}) #todo(tx=nil)
    @q.each(opts) do |entity|
      yield(@model_class.new_from_entity(entity))
    end
  end
  def collect(opts={}) #todo(tx=nil)
    collected = []
    @q.each(opts) do |entity|
      collected << yield(@model_class.new_from_entity(entity))
    end
    collected
  end
  def keys(opts={}) #todo(tx=nil)
    keys = []
    self.keys_only
    @q.each(opts) do |entity|
      keys << entity.key
    end
    keys
  end
end
end
