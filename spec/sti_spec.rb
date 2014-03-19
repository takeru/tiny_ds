require File.dirname(__FILE__) + '/spec_helper'

class Page < TinyDS::Base
  property :title, :string
  property :type, :type
end

class ExtendedPage < Page
  property :extra_data, :string
end

class FurtherExtendedPage < Page
  property :extra_extra_data, :string
end

describe ExtendedPage do
  before :each do
    AppEngine::Testing.install_test_datastore
  end
  after :all do
    AppEngine::Testing.teardown
  end
  it "should allow assigning of base attributes" do
    subject.attributes = {:title => 'aaa'}
    subject.title.should == 'aaa'
  end
  it "should return base class Page as its kind" do
    subject.key.kind.should == 'Page'
  end
  it "should update the type field on save" do
    subject.save
    subject.type.should == 'ExtendedPage'
  end
  it "should return the subclass from a find on the parent" do
    subject.save
    p2 = Page.get(subject.key)
    p2.should be_kind_of(ExtendedPage)
  end
=begin
  describe "new_from_entity" do
    it "should build from low-entity" do
      ent = FurtherExtendedPage.create({:title=>"aaa", :extra_extra_data=>'444', :extra_data=>"x"}).entity

      a1 = FurtherExtendedPage.new_from_entity(ent)
      a1.title.should == "aaa"
      a1.extra_extra_data.should   == '444'
      a1.extra_data.should  == "x"
    end
  end
=end

end
