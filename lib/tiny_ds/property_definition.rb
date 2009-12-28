module TinyDS
class PropertyDefinition
  def initialize(pname, ptype, opts)
    @pname = pname
    @ptype = ptype
    @opts  = opts
  end
  def default_value
    raise "no default." unless has_default?
    default = @opts[:default]
    case default
    when Proc
      default.call
    else
      default
    end
  end
  def has_default?
    @opts.has_key?(:default)
  end
  def to_ds_value(v)
    return nil if v.nil?
    case @ptype
    when :string
      v.to_s
    when :integer
      v.to_i
    when :text
      com.google.appengine.api.datastore::Text.new(java.lang.String.new(v))
    when :time
      Time.parse(v.to_s)
   #when :list
   #  raise "todo"
    else
      raise "unknown type @ptype=#{@ptype}"
    end
  end
  def to_ruby_value(ds_v)
    return nil if ds_v.nil?
    case @ptype
    when :string
      ds_v.to_s
    when :integer
      ds_v.to_i
    when :text
        ds_v.to_s
    when :time
      Time.parse(ds_v.to_s)
      #when :list
      #  raise "todo"
    else
      raise "unknown type @ptype=#{@ptype}"
    end
  end
end
end
