require "time"

module TinyDS
class Base
  class << self; attr_accessor :_property_definitions; end
  RESERVED_PROPERTY_NAME = [:id, :name, :key, :entity, :parent_key, :parent]
  VALID_PROPERTY_TYPE = [:string, :integer, :float, :text, :time, :list]
  def self.property(pname, ptype, opts={})
    pname = pname.to_sym
    if RESERVED_PROPERTY_NAME.include?(pname)
      raise "property name '#{pname}' is reserved."
    end
    property_definitions[pname] = PropertyDefinition.new(pname, ptype, opts)
  end

  def self.property_definitions
    self._property_definitions ||= {}
  end

  def self.property_definition(name)
    property_definitions[name.to_sym] or raise "unknown property='#{name}'"
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

  # kind-string of entity
  def self.kind
    name
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
    new(nil, :entity=>_entity)
  end
  attr_reader :entity

  def new_record?
    @new_record
  end

  # foo.save
  def save
    do_save
    true
  end

  def do_save
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

  def __before_save_set_timestamps
    if self.class.property_definitions[:created_at] && new_record?
      self.created_at = Time.now
    end
    if self.class.property_definitions[:updated_at]
      self.updated_at = Time.now
    end
  end

  # Foo.get(key)
  def self.get!(key)
    self.new_from_entity(LowDS.get(key, :kind=>self.kind))
  end
  def self.get(key)
    get!(key)
  rescue AppEngine::Datastore::EntityNotFound => e
    nil
  end

  def self._get_by_id_or_name!(id_or_name, parent)
    key = if parent
            parent = to_key(parent)
            kfb = LowDS::KeyFactory::Builder.new(parent)
            kfb.addChild(kind, id_or_name)
            kfb.key
          else
            LowDS::KeyFactory::Builder.new(kind, id_or_name).key
          end
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
    if id.kind_of?(String) && id==id.to_i.to_s
      id = id.to_i
    end
    _get_by_id_or_name!(id, parent)
  rescue AppEngine::Datastore::EntityNotFound => e
    nil
  end
  def self.get_by_name(name, parent=nil)
    _get_by_id_or_name!(name, parent)
  rescue AppEngine::Datastore::EntityNotFound => e
    nil
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
    destroy(query.keys)
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
    prop_def.to_ruby_value(@entity[k])
  end

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
end
end
