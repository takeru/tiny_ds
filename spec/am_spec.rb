require File.dirname(__FILE__) + '/spec_helper'

require 'active_model'

class ActiveComment < TinyDS::Base
  include ActiveModel::Validations
  property :num,        :integer
  property :title,      :string
  property :body,       :text
  property :flag,       :integer, :default=>5
  property :new_at,     :time,    :default=>proc{ Time.now }
  property :rate,       :float
  property :updated_at, :time
  property :created_at, :time
  property :view_at,    :time
end


describe ActiveComment do
  before :each do
    AppEngine::Testing.install_test_datastore
  end
  after :all do
    AppEngine::Testing.teardown
  end
  it_should_behave_like "ActiveModel"

  it "should return string key for to_param" do
    c1 = ActiveComment.create({},{:id => 4})
    c1.to_param.should == c1.to_key.to_s
    c1.to_param.should == 'agR0ZXN0chMLEg1BY3RpdmVDb21tZW50GAQM'
  end

  it "should key array for to_key" do
    c1 = ActiveComment.create({},{:id => 4})
    c1.to_key.should == [c1.key]
  end

end
