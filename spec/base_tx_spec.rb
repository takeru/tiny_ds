require File.dirname(__FILE__) + '/spec_helper'

class User < TinyDS::Base
  property :nickname, :string
  property :money,    :integer
  def apply_recv_money(amount)
    self.money += amount
    return [self]
  end
end

describe "BaseTx" do
  before :all do
    AppEngine::Testing.install_test_env
    AppEngine::Testing.install_test_datastore
  end

  describe "should move money A to B" do
    before :each do
      User.destroy_all
      TinyDS::BaseTx::SrcJournal.destroy_all
      TinyDS::BaseTx::DestJournal.destroy_all

      @userA = User.create(:nickname=>"userA", :money=>10000)
      @userB = User.create(:nickname=>"userB", :money=>10000)
      @amount = 500

      User.count.should                         == 2
      TinyDS::BaseTx::SrcJournal.count.should  == 0
      TinyDS::BaseTx::DestJournal.count.should == 0
    end

    describe "create a journal" do
      before :each do
        @journal = nil
        TinyDS.tx do
          @userA = @userA.reget
          @userA.money -= @amount
          @journal = TinyDS::BaseTx.build_journal(
            @userA,
            {:class=>User, :key=>@userB.key}, # @userB,
            :apply_recv_money,
            @amount
          )
          TinyDS.batch_save([@userA, @journal])
        end

        @userA.reget.money.should        ==  9500
        @userB.reget.money.should        == 10000
        @journal.reget.args.size.should  ==     1
        @journal.reget.args[0].should    ==   500
        @journal.reget.status.should     == "created"
        @journal.reget.created_at.should_not be_nil
        TinyDS::BaseTx::SrcJournal.count.should  == 1
        TinyDS::BaseTx::DestJournal.count.should == 0
      end

      def common_specs_for_after_apply
        @userA.reget.money.should        ==  9500
        @userB.reget.money.should        == 10500
        @journal.reget.status.should     == "done"
        TinyDS::BaseTx::SrcJournal.count.should  == 1
        TinyDS::BaseTx::DestJournal.count.should == 1

        TinyDS::BaseTx.apply(@journal.key)

        @userA.reget.money.should        ==  9500
        @userB.reget.money.should        == 10500
      end

      it "apply by instance" do
        TinyDS::BaseTx.apply(@journal)
        common_specs_for_after_apply
      end
      it "apply by key" do
        TinyDS::BaseTx.apply(@journal.key)
        common_specs_for_after_apply
      end
      it "apply_pendings" do
        TinyDS::BaseTx.apply_pendings
        common_specs_for_after_apply
      end
    end
  end
end
