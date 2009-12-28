module TinyDS
  class Base
    def valid?
      true # todo
    end
    def self.create!(attrs={}, opts={})
      m = new(attrs, opts)
      m.save!
      m
    end
    def save
      save!
      true
    rescue RecordInvalid => e
      false
    end
    def save!
      unless valid?
        raise RecordInvalid
      end
      do_save
    end
  end
  class RecordInvalid < StandardError
  end
end
