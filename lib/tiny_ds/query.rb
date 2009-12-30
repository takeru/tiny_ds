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
  def filter(name, operator, value)
    # TODO check neme or raise
    unless @model_class.property_definitions[name.to_sym]
      raise "unknown property='#{name}'"
    end
    @q.filter(name, operator, value)
    self
  end
  def sort(name, dir=:asc)
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
  def one #todo(tx=nil)
    @model_class.new_from_entity(@q.entity)
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
