<% min = max = 10
   Array(attributes).each do |attribute|
     if TinyDS::Base::RESERVED_PROPERTY_NAME.include? attribute.name.to_sym
       raise "reserved property name '#{attribute.name}'"
     elsif !TinyDS::Base::VALID_PROPERTY_TYPE.include? attribute.type
       raise "unknown property type '#{attribute.type}'"
     end
     max = attribute.name.size if attribute.name.size > max -%>
<% end -%>
class <%= class_name %> < TinyDS::Base
<% Array(attributes).each do |attribute|
     pad = max - attribute.name.size
     %>  property :<%= attribute.name
     %>, <%= " " * pad  %><%= ":#{attribute.type}" %>
<% end -%>
<% unless options[:skip_timestamps] -%>
  property :created_at, <%= " " * (max - min) %>:time
  property :updated_at, <%= " " * (max - min) %>:time
<% end -%>
end
