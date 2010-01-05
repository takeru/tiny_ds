require 'rails_generator/generators/components/model/model_generator'
require 'active_record'
 
class RspecTdModelGenerator < ModelGenerator
 
  def manifest
    record do |m|
 
      # Check for class naming collisions.
      m.class_collisions class_path, class_name
 
      # Model, spec, and fixture directories.
      m.directory File.join('app/models',  class_path)
      m.directory File.join('spec/models', class_path)
 
      # Model class, spec and fixtures.
      m.template 'td_model:model.rb', File.join('app/models',  class_path, "#{file_name}.rb")
      m.template 'model_spec.rb',     File.join('spec/models', class_path, "#{file_name}_spec.rb")
 
    end
  end
 
end
