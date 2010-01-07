module TinyDS
  class Base
    # @user.tx{                   |u|    u.name="john" }
    # @user.tx(10){               |u| u.name="john" }
    # @user.tx(    :name=>"john")
    # @user.tx(10, :name=>"john")
    # @user.tx(    :name=>"john"){|u| u.name="JOHN" }
    # @user.tx(10, :name=>"john"){|u| u.name="JOHN" }
    def tx_update(*args)
      retries = 3
      retries = args.shift if args.first.kind_of?(Integer)
      attrs   = args.shift
      raise ArgumentError if args.size!=0
      raise ArgumentError if !block_given? && attrs.nil?
      obj = nil
      TinyDS.tx(retries) do
        obj = self.class.get(self.key)
        # raise if obj.version != self.version
        obj.attributes = attrs if attrs
        yield(obj) if block_given?
        obj.save!
      end
      obj
    end
  end
end
