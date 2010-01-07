require File.dirname(__FILE__) + '/spec_helper'


describe "transaction" do
  it "should push/pop tx" do
    ds = AppEngine::Datastore.service
    proc{ ds.getCurrentTransaction }.should raise_error(NativeException, "java.lang.IllegalStateException: java.util.NoSuchElementException")
    ds.getActiveTransactions.to_a.size.should == 0

    tx1 = ds.beginTransaction
    # [tx1]
    tx1.should be_kind_of(com.google.appengine.api.datastore.Transaction)
    tx1.should == ds.getCurrentTransaction
    ds.getActiveTransactions.to_a.size.should == 1

    tx2 = ds.beginTransaction
    # [tx2, tx1]
    tx2.should be_kind_of(com.google.appengine.api.datastore.Transaction)
    tx2.should == ds.getCurrentTransaction
    ds.getActiveTransactions.to_a.size.should == 2
    ds.getActiveTransactions.to_a[0].should == tx2
    ds.getActiveTransactions.to_a[1].should == tx1

    tx3 = ds.beginTransaction
    # [tx3, tx2, tx1]
    tx3.should be_kind_of(com.google.appengine.api.datastore.Transaction)
    tx3.should == ds.getCurrentTransaction
    ds.getActiveTransactions.to_a.size.should == 3
    ds.getActiveTransactions.to_a[0].should == tx3
    ds.getActiveTransactions.to_a[1].should == tx2
    ds.getActiveTransactions.to_a[2].should == tx1

    tx3.commit
    # [tx2, tx1]
    tx2.should == ds.getCurrentTransaction
    ds.getActiveTransactions.to_a.size.should == 2
    ds.getActiveTransactions.to_a[0].should == tx2
    ds.getActiveTransactions.to_a[1].should == tx1

    tx4 = ds.beginTransaction
    # [tx4, tx2, tx1]
    tx4.should be_kind_of(com.google.appengine.api.datastore.Transaction)
    tx4.should == ds.getCurrentTransaction
    ds.getActiveTransactions.to_a.size.should == 3
    ds.getActiveTransactions.to_a[0].should == tx4
    ds.getActiveTransactions.to_a[1].should == tx2
    ds.getActiveTransactions.to_a[2].should == tx1

    tx2.commit
    # [tx4, tx1]
    tx4.should == ds.getCurrentTransaction
    ds.getActiveTransactions.to_a.size.should == 2
    ds.getActiveTransactions.to_a[0].should == tx4
    ds.getActiveTransactions.to_a[1].should == tx1

    tx1.rollback
    # [tx4]
    tx4.should == ds.getCurrentTransaction
    ds.getActiveTransactions.to_a.size.should == 1
    ds.getActiveTransactions.to_a[0].should == tx4

    tx4.rollback
    # []
    ds.getCurrentTransaction(nil).should be_nil
    ds.getActiveTransactions.to_a.size.should == 0
  end

  it "should be default is NONE" do
    dsf = com.google.appengine.api.datastore.DatastoreServiceFactory
    dsc = dsf.getDefaultDatastoreConfig
    dsc.should == com.google.appengine.api.datastore.DatastoreConfig::DEFAULT
    dsc.getImplicitTransactionManagementPolicy.should == com.google.appengine.api.datastore.ImplicitTransactionManagementPolicy::NONE
  end
end
