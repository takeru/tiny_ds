module TinyDS
  class Base
    # @user.tx{                   |u| u.name="john" }
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
      TinyDS.tx(:retries=>retries) do
        obj = get_self_and_check_lock_version
        obj.attributes = attrs if attrs
        yield(obj) if block_given?
        obj.save!
      end
      obj
    end
    def get_self_and_check_lock_version
      obj = self.class.get(self.key)
      if self.class.has_property?(:lock_version)
        if obj.lock_version != self.lock_version
          raise StaleObjectError.new
        end
        obj.lock_version += 1
      end
      obj
    end
    class StaleObjectError < StandardError
    end
  end
end
