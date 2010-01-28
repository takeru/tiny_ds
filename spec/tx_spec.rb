require File.dirname(__FILE__) + '/spec_helper'

# http://www.slideshare.net/ashigeru/ajn4
#   1. EGでのACIDトランザクションの仕組み
#   2. パターン「read-modify-write」1エンティティの書き換え
#   3. パターン「トランザクションの合成」同一EG複数エンティティの書き換え
#   4. パターン「ユニーク制約」id/name指定を用いたユニーク制約の実現
#   5. パターン「べき等な処理」1回以上複数回実行されても結果は1回だけ実行された状態になる処理
#   6. パターン「exactly-once」確実に1回だけ実行される処理。2回以上実行されない処理
#   7. パターン「BASE Transaction」過渡的な状態があるトランザクション

=begin
describe "TinyDS::Transaction" do
  describe "(1) EG transaction" do
    it "should work" do
      Tx.atomic{
      }
    end
  end
  describe "(2) read_modify_write" do
  end
  describe "(3) 2 entities read_modify_write" do
  end
  describe "(4) unique value" do
    it "should work" do
      User.create(props, {:name=>"hoge@example.com", :check_unique=>true})
    end
    # name/id が指定された場合ユニークチェックをする
    # デフォルトでする / しない？
    # transaction内の場合 => ...
    # transaction外の場合 => ...
  end
  describe "(5) idempotent" do
    idempotent_key = TxFlag.generate_key(@parent.key, unique_value)
    args = {:amount=>5000}
    Tx.idempotent(idempotent_key, args) do |args|
      # Tx.atomic{
      #   flag = get(idempotent_key)
      #   raise :not_unique if flag
      #   yield(args){
      @user.money += args[:amount]
      #   }
      # }
    end
    # @parentの子としてIdempotentFlagが作成される
    # @parentと(IdempotentFlagと)処理内で使うすべてのentityは同一EGである必要がある
  end
  describe "(6) exactly_once" do
    exactly_once_key = TxFlag.generate_key(@parent.key, unique_value)
    Tx.exactly_once(exactly_once_key, args) do |args|
#      idempotent_key = exactly_once_key
#      TQ.enqueue(idempotent_key, args, proc{|idempotent_key,args|
#                   Tx.idempotent(idempotent_key, args) do |args|
                     user = User.get(args[:user_id])
                     user.money += 5000
                     user.save
#                   end
#                 }.serialize)
    end
  end
  describe "(7) base_transaction" do
    base_tx_key = TxFlag.generate_key(@parent.key, unique_value)
    Tx.base_transaction(args, procA, procB) do
#      Tx.atomic{|tx1|
#        yield(args){
           # (procA)
           a = get(args[:userA_key])
           a.money -= args[:ampunt]
           a.save
#        }
#        exactly_once_key = ...
#        Tx.exactly_once_key(exactly_once_key, args){
           # (procB)
           b = get(args[:userB_key])
           b.money += args[:ampunt]
           b.save
#        }
#      }
    end
  end
end
=end
