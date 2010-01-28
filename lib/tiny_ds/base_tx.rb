# memo デプロイ時に未完了のトランザクションがあってトランザクション定義がかわったら？version???
module TinyDS
class BaseTx
  def src_phase(src, args)
    raise "no impl."
  end
  def dest_phase(dest, args)
    raise "no impl."
  end
  def self.tx_kind
    name
  end
  def roll_forward_retries_limit
    100
  end
  def tx_retries
    3
  end
  attr_reader :tx_key

  # トランザクション実行
  #          :  src_phase   dest_phase
  #   raised :    failed      ----
  #   false  :    OK          failed
  #   true   :    OK          OK
  def self.exec(src, dest, args={})
    tx = new
    tx.create_tx(src, dest, args)
    begin
      tx.roll_forward
    rescue AppEngine::Datastore::TransactionFailed => e
      return false
    end
    return true
  end

  def self.roll_forward_all(limit=50)
    pending_tx_query.each(:limit=>limit) do |tx_src|
      tx = new
      tx.restore_tx(tx_src)
      begin
        tx.roll_forward
      rescue => e
        #p "roll_forward failed. tx=[#{tx.tx_key}] e=[#{e.inspect}]"
      end
    end
    nil
  end

  def self.pending_tx_query(status="pending", dire=:asc) # pending/done/failed
    TxSrc.query.
      filter(:tx_kind, "==", tx_kind).
      filter(:status,  "==", status).
      sort(:created_at, dire)
  end

  # doneなTxSrcと対応するTxDoneを削除する
#  def self.delete_done_tx
#  end

  class TxSrc < Base
    property :tx_kind,                   :string
    property :dest_key,                  :string
    property :status,                    :string,  :default=>"pending"
    property :roll_forward_failed_count, :integer, :default=>0
    property :args,                      :text
    property :created_at,                :time
    property :done_at,                   :time
  end

  # トランザクション前半
  #   TODO TxIDを指定できるようにする。TxSrc#key.nameにTxIDを指定して重複実行防止
  def create_tx(src, dest, args)
    tx_src = nil
    TinyDS.tx(:force_begin=>true, :retries=>tx_retries){
      src = src.class.get(src.key)
      src_phase(src, args)
      src.save!

      attrs = {
        :tx_kind  => self.class.tx_kind,
        :dest_key => dest.key.to_s,
        :args     => args.to_yaml,
      }
      tx_src = TxSrc.create!(attrs, :parent=>src) # srcがparent, tx_srcがchild
      # COMMIT:「srcの処理(=src_phase)、TxSrc作成」
    }
    @tx_key = tx_src.key
    nil
  end

  def restore_tx(tx_src)
    @tx_key = tx_src.key
    nil
  end

  class TxDone < Base
    property :done_at, :time
  end

  # トランザクション後半
  def roll_forward
    tx_src = TxSrc.get(@tx_key)

    TinyDS.tx(:force_begin=>true, :retries=>tx_retries){
      dest_key = LowDS::KeyFactory.stringToKey(tx_src.dest_key)
      dest = dest_key.kind.constantize.get(dest_key)
      done_name = "TxDone_#{@tx_key.to_s}"
      done_key = LowDS::KeyFactory.createKey(dest.key, TxDone.kind, done_name)
      begin
        TxDone.get!(done_key)
        # なにもしない : TxDoneが存在しているということはdest_phaseは処理済み
      rescue AppEngine::Datastore::EntityNotFound => e
        # TxDoneが無い→dest_phaseが未実行
        attrs = {:done_at=>Time.now}
        tx_done = TxDone.create!(attrs, :parent=>dest, :name=>done_name)
        dest_phase(dest, YAML.load(tx_src.args)) # destの処理を実行
        dest.save!
      end
      # memo: done_keyが同じTxDoneをcommitしようとするとTransactionFailedになるはず→dest_phaseもキャンセル
      # COMMIT:「destの処理(=dest_phase)、TxDone作成」
    }

    # TxSrc#statusをdoneに
    TinyDS.tx(:force_begin=>true, :retries=>tx_retries){
      tx_src = TxSrc.get!(@tx_key)
      if tx_src.status=="pending"
        tx_src.status = "done"
        tx_src.done_at = Time.now
        tx_src.save!
      end
    }
    return true
  rescue => e
    puts e.inspect
    TinyDS.tx(:force_begin=>true, :retries=>tx_retries){
      tx_src = TxSrc.get!(@tx_key)
      tx_src.roll_forward_failed_count += 1
      if roll_forward_retries_limit < tx_src.roll_forward_failed_count
        tx_src.status = "failed"
      end
      tx_src.save!
    }
    return false
  end

  if false
    require "benchmark"
    def create_tx(src, dest, args)
      RAILS_DEFAULT_LOGGER.info ["create_tx", Benchmark.measure{
        _create_tx(src, dest, args)
      }].inspect
    end
    def roll_forward
      RAILS_DEFAULT_LOGGER.info ["roll_forward", Benchmark.measure{
        _roll_forward
      }].inspect
    end
  end
end
end
