<% min = max = 10
   reserved_names = %(id key) # TODO: should be TinyDS constants
   valid_types = %(string integer text time list)
   Array(attributes).each do |attribute|
     if reserved_names.include? attribute.name.to_s.downcase
       raise "reserved property name '#{attribute.name}'"
     elsif !valid_types.include? attribute.type.to_s.downcase
       raise "unknown property type '#{attribute.type}'"
     end
     max = attribute.name.size if attribute.name.size > max -%>
<% end -%>
class <%= class_name %> < TinyDS::Base
<% Array(attributes).each do |attribute|
     pad = max - attribute.name.size
     %>  property :<%= attribute.name
     %>, <%= " " * pad  %><%= ":#{attribute.type.to_s.downcase}" %>
<% end -%>
<% unless options[:skip_timestamps] -%>
  property :created_at, <%= " " * (max - min) %>:time
  property :updated_at, <%= " " * (max - min) %>:time
<% end -%>
end
