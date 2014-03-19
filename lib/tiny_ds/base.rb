require "time"

module TinyDS
class Base
  class << self; attr_accessor :_property_definitions; end
  RESERVED_PROPERTY_NAME = [:id, :name, :key, :entity, :parent_key, :parent]
  VALID_PROPERTY_TYPE = [:string, :integer, :float, :boolean, :text, :time, :list, :type, :user, :key]
  def self.property(pname, ptype, opts={})
    pname = pname.to_sym
    if RESERVED_PROPERTY_NAME.include?(pname)
      raise "property name '#{pname}' is reserved."
    end
    (self._property_definitions||={})[pname] = PropertyDefinition.new(pname, ptype, opts)
    define_method "#{pname}" do
      get_property(pname)
    end
    define_method "#{pname}=" do |value|
      set_property(pname, value)
    end
  end

  def self.property_definitions
    if superclass != Base
      defs = superclass.property_definitions
    else
      defs = {}
    end
    defs.merge(self._property_definitions ||= {})
  end

  def self.property_definition(name)
    property_definitions[name.to_sym] or raise "unknown property='#{name}'"
  end

  def self.valid_property?(name, context) # context => :filter,:sort
    name = name.to_sym
    if name==:__key__
      true
    elsif property_definitions[name.to_sym]
      true
    else
      false
    end
  end

  def self.has_property?(name)
    property_definitions.has_key?(name.to_sym)
  end

  def self.default_attrs
    attrs = {}
    property_definitions.each do |pname,pdef|
      if pdef.has_default?
        attrs[pname] = pdef.default_value
      end
    end
    attrs
  end

  def self.sti_property_definition
    name, sti_def = property_definitions.detect {|pname, pdef| pdef.ptype == :type}
    sti_def
  end
  def self.sti?
    !!sti_property_definition
  end
    

  # kind-string of entity
  def self.kind
    if superclass != Base && superclass.sti?
      superclass.kind
    else
      name
    end
  end

  #include ActiveModel::Naming
#  def self.model_name # for form-builder
#    @model_name ||= ::ActiveModel::Name.new(self, kind)
#  end

  # foo.key
  def key
    @entity.key
  end
  def id
    key.id
  end
  def name
    key.name
  end

  # foo.parent_key
  def parent_key
    @entity.parent
  end

  def self.to_key(m)
    case m
    when AppEngine::Datastore::Key
      m
    when AppEngine::Datastore::Entity
      m.key
    when String
      LowDS::KeyFactory.stringToKey(m)
    else
      if m.kind_of?(Base)
        m.key
      else
        raise "unknown key type #{m.class}/#{m.inspect}"
      end
    end
  end

  # KeyRange allocateIds(java.lang.String kind, long num)
  def self.allocate_ids(num)
    AppEngine::Datastore.allocate_ids(kind, num) # KeyRange
  end
  def self.allocate_id
    allocate_ids(1).start # Key
  end

  # KeyRange allocateIds(Key parent, java.lang.String kind, long num)
#  def allocate_ids(kind, num)
#    todo
#  end
#  def allocate_id(kind)
#    todo
#  end

  # Foo.create({:title=>"hello",...}, :parent=>aaa, :id=>bbb, :name=>ccc, :key=>...)
  def self.create(attrs={}, opts={})
    m = new(attrs, opts)
    m.save
    m
  end

  # Foo.new
  def initialize(attrs={}, opts={})
    unless opts.has_key?(:entity)
      if opts[:parent] && opts[:parent].kind_of?(Base)
        opts = opts.dup
        opts[:parent] = opts[:parent].entity
      end
      @entity = LowDS.build(self.class.kind, {}, opts)
      self.attributes = self.class.default_attrs.merge(attrs || {})
      @new_record = true
    else
      @entity = opts.delete(:entity) or raise "opts[:entity] is nil."
      @new_record = false
    end
  end

  def self.new_from_entity(_entity)
    clazz = self
    if sti_def = self.sti_property_definition
      if type_name = _entity[sti_def.pname]
        clazz = constantize(type_name)
      end
    end
    clazz.new(nil, :entity=>_entity)
  end
  attr_reader :entity

  def new_record?
    @new_record
  end

  def persisted?
    !new_record?
  end

  def to_param
    self.key.to_s if persisted?
  end

  def to_key
    [self.key] if persisted?
  end

  # foo.save
  def save
    do_save
    true
  end

  def do_save
    if @read_only
      # raise "entity is readonly."
      logger.warn "entity is readonly. key=[#{self.key.inspect}]"
    end
    __before_save_set_type
    __before_save_set_timestamps
#    if @new_record && @entity.key && parent
#      TinyDS.tx{
#        if LowDS.get(@entity.key)
#          raise KeyIsAlreadyTaken
#        end
#        LowDS.save(@entity)
#      }
#    else
      LowDS.save(@entity)
#    end
    @new_record = false
    nil
  end
#  class KeyIsAlreadyTaken < StandardError
#  end
  def __before_save_set_type
    if type_prop = self.class.sti_property_definition
      self.set_property(type_prop.pname, self.class.name)
    end
  end

  def __before_save_set_timestamps
    if self.class.has_property?(:created_at) && new_record?
      self.created_at = Time.now
    end
    if self.class.has_property?(:updated_at)
      self.updated_at = Time.now
    end
  end

  # Foo.get(key)
  def self.get!(key)
    ent = LowDS.get(key)
    raise "kind missmatch. #{ent.kind}!=#{self.kind}" if ent.kind != self.kind
    self.new_from_entity(ent)
  end
  def self.get(key)
    get!(key)
  rescue AppEngine::Datastore::EntityNotFound => e
    nil
  end

  def self.build_key(id_or_name, parent)
    if parent
      parent = to_key(parent)
      kfb = LowDS::KeyFactory::Builder.new(parent)
      kfb.addChild(kind, id_or_name)
      kfb.key
    else
      LowDS::KeyFactory::Builder.new(kind, id_or_name).key
    end
  end
  def self._get_by_id_or_name!(id_or_name, parent)
    key = build_key(id_or_name, parent)
    get!(key)
  end

  def self.get_by_id!(id, parent=nil)
    if id.kind_of?(String) && id==id.to_i.to_s
      id = id.to_i
    end
    raise "id is not Integer" unless id.kind_of?(Integer)
    _get_by_id_or_name!(id, parent)
  end
  def self.get_by_name!(name, parent=nil)
    raise "id is not String" unless name.kind_of?(String)
    _get_by_id_or_name!(name, parent)
  end
  def self.get_by_id(id, parent=nil)
    get_by_id!(id, parent)
  rescue AppEngine::Datastore::EntityNotFound => e
    nil
  end
  def self.get_by_name(name, parent=nil)
    get_by_name!(name, parent)
  rescue AppEngine::Datastore::EntityNotFound => e
    nil
  end

  # batch get
  def self.get_by_keys(keys)
    key_and_classes = keys.collect{|key|
      [key, self]
    }
    TinyDS.batch_get(key_and_classes)
  end
  def self.get_by_ids(ids, parent=nil)
    key_and_classes = ids.collect{|id|
      [build_key(id, parent), self]
    }
    TinyDS.batch_get(key_and_classes)
  end
  def self.get_by_names(names, parent=nil)
    get_by_ids(names, parent)
  end

#  # Foo.find
#  def self.find(*args)
#    raise "todo"
#    direction = dire==:desc ? AppEngine::Datastore::Query::DESCENDING : AppEngine::Datastore::Query::ASCENDING
#    AppEngine::Datastore::Query.new("TxSrc").
#      filter(:tx_kind, AppEngine::Datastore::Query::EQUAL, tx_kind).
#      filter(:status,  AppEngine::Datastore::Query::EQUAL, status).
#      sort(:created_at, direction)
#  end

  def self.query
    Query.new(self)
  end

  def self.count
    query.count
  end

  # foo.destroy
  def destroy
    self.class.destroy(self)
  end

  # Foo.destroy([model, entity, key, ...])
  def self.destroy(array)
    array = [array] unless array.kind_of?(Array)
    keys = array.collect do |m|
      to_key(m)
    end
    AppEngine::Datastore.delete(keys)
  end
  def self.destroy_all
    loop do
      _keys = query.keys(:limit=>500)
      break if _keys.empty?
      destroy(_keys)
    end
  end

  # set readonly flag
  def read_only
    @read_only = true
    self
  end

  # re-get by self.key for transaction
  def reget
    self.class.get(self.key)
  end

  def tx(opts={}, &block)
    TinyDS.tx(opts) do
      m = self.reget
      yield(m)
    end
  end

  # set attributes
  def attributes=(attrs)
    attrs.each do |k,v|
      set_property(k, v)
    end
    nil
  end

  # set property-value into @entity
  def set_property(k,v)
    prop_def = self.class.property_definition(k)
    ds_v = prop_def.to_ds_value(v)
    if ds_v.nil?
      @entity.removeProperty(k)
    else
      if prop_def.index?
        @entity[k] = ds_v
      else
        @entity.setUnindexedProperty(k, ds_v)
      end
    end
    # todo cache value read/write
  end

  # get property-value from @entity
  def get_property(k)
    prop_def = self.class.property_definition(k)
    v = prop_def.to_ruby_value(@entity[k])
    if v.nil?
      if prop_def.has_default?
        v = prop_def.default_value
        unless v.nil?
          set_property(k,v)
        end
      end
    end
    v
  end

  def ==(other)
    return true if equal?(other)
    return false unless other.kind_of?(Base)
    return key == other.key
  end

  def eql?(other)
    return true if equal?(other)
    return false unless other.kind_of?(Base)
    return key.eql? other.key
  end

  def hash
    key.hash
  end

=begin
  def method_missing(m, *args)
    k, is_set = if m.to_s =~ /(.+)=$/
                  [$1.to_sym, true]
                else
                  [m.to_sym, false]
                end
    if prop_def = self.class.property_definitions[k]
      # TODO define method.
      if is_set
        raise if args.size!=1
        set_property(k, args.first)
      else
        raise if args.size!=0
        get_property(k)
      end
    else
      super(m, *args)
    end
  end
=end

  def logger
    self.class.logger
  end
  def self.logger
    @@logger ||= Logger.new($stderr)
  end
  def self.logger=(l)
    @@logger = l
  end
end
end
