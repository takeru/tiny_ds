module TinyDS
  class Base
    # convert calls from Rails generated scaffold
    def self.all; self.query.all; end
    def self.find(id); self.get_by_id(id); end
    def to_param; id.to_s; end
    def update_attributes(values); self.attributes = values; save; end
    def errors; []; end # TODO: add basic validations
  end
end
