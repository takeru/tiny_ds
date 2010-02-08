# memo デプロイ時に未完了のトランザクションがあってトランザクション定義がかわったら？version???
module TinyDS
  class BaseTx
    class SrcJournal < ::TinyDS::Base
      property :dest_klass,        :string, :index=>false
      property :dest_key,          :string, :index=>false
      property :method_name,       :string, :index=>false
      property :args_yaml,         :text
      property :copy_failed_count, :integer, :default=>0
      def self.kind; "__SrcJournal" end
      def key_string
        self.key.to_s
      end
    end
    class DestJournal < ::TinyDS::Base
      property :dest_klass,         :string, :index=>false
      property :method_name,        :string, :index=>false
      property :args_yaml,          :text
      property :apply_failed_count, :integer, :default=>0
      def self.kind; "__DestJournal" end
      def self.src_journal_exist?(dest_journal_key)
        src_journal_key = dest_journal_key.name
        if SrcJournal.get(src_journal_key)
          true
        else
          false
        end
      end
    end
    class << self
      # (STEP1) create_journal
      # create src_journal as child of src.
      # usage:
      #   TinyDS.tx do # EG-A
      #     entityA1 = Ent.get(...)
      #     entityA1.save
      #     TinyDS::BaseTx.create_journal(
      #       src,  # entity of EG-A
      #       dest, # entity of EG-B
      #       :apply_some,
      #       arg1, arg2, arg3, ...
      #     )
      #     # or entityA1.create_journal(dest, values)
      #     # or entityA1.base_call(dest, method, arg1, arg2, ...)
      #   end
      def create_journal(src, dest, method_name, *args)
        # TODO raise if current_tx is none
        src_journal = SrcJournal.create({
                        :dest_klass  => dest.class.name,
                        :dest_key    => dest.key.to_s,
                        :method_name => method_name.to_s,
                        :args_yaml   => args.to_yaml
                      }, :parent=>src)
        src_journal
      end

      # (STEP2) copy_journal
      # create dest_journal as child of dest.
      # 「dest_journalがある」&&「src_journalがない」状態になるまで繰り返し実行される(cronなどで)
      # src_journalの削除に失敗した場合、成功するまでcopy_journalが実行される。
      def copy_journal(src_journal)
        raise "not SrcJournal." unless src_journal.kind_of?(SrcJournal)

        # src_journalからdest_journalにコピーする
        dest_journal = nil
        TinyDS.tx(:retries=>10, :force_begin=>true){ # EG-B
          dest_journal = DestJournal.get_by_name(src_journal.key_string, src_journal.dest_key)
          unless dest_journal
            dest_journal = DestJournal.create({
              :dest_klass  => src_journal.dest_klass,
              :method_name => src_journal.method_name,
              :args_yaml   => src_journal.args_yaml
             },
            { :parent => src_journal.dest_key,
              :name   => src_journal.key_string
             })
          end
        }

        # (dest_journalができたら)src_journalを削除する。
        src_journal.destroy

        return dest_journal
      end
      def copy_journal_all(opts={})
        limit          = opts[:limit]          || 10
        copy_retry_max = opts[:copy_retry_max] || 10
        SrcJournal.query.filter(:copy_failed_count, "<", copy_retry_max).
                         sort(:copy_failed_count, :asc).
                         each(:limit=>limit) do |src_journal|
          begin
            copy_journal(src_journal)
         #rescue TransactionFailed => e # java.util.ConcurrentModificationException
          rescue Object => e
            begin
              TinyDS.tx(:force_begin=>true) do
                src_journal = SrcJournal.get(src_journal.key)
                if src_journal
                  src_journal.copy_failed_count += 1
                  src_journal.save
                end
              end
            rescue TransactionFailed => e
              # ignore
            end
          end
        end
        nil
      end

      #=============================================================================================
      # (STEP3) apply_journal
      # 「dest_journalがない」状態になるまで繰り返し実行される
      # 「src_journalがない」状態になっていない場合はapplyしない
      #  destのメソッドでEG-Bのtx内で操作を行う
      #  def apply_some(arg1,arg2,arg3,arg4,...)
      #    self.aaa += arg1
      #    self.bbb += arg2
      #    self.ccc += arg3
      #    self.save
      #    entX = Ent.get(arg4)
      #    entX.ddd += arg5
      #    entX.save
      #  end
      def apply_journal(dest_journal_key, opts={})
        if dest_journal_key.kind_of?(DestJournal)
          dest_journal_key = dest_journal_key.key
        end
        if DestJournal.src_journal_exist?(dest_journal_key) #dest_journal.src_journal_exist?
          return false
        end

        # destの'method_name'を実行する＆dest_journalを削除する
        TinyDS.tx(:retries=>10, :force_begin=>true){ # EG-B
          dest_journal = DestJournal.get(dest_journal_key)
          return true unless dest_journal
          klass = const_get(dest_journal.dest_klass)
          dest = klass.get(dest_journal.parent_key)
          dest.send(dest_journal.method_name, *(YAML.load(dest_journal.args_yaml)))
          dest_journal.destroy
        }
        return true
      end
      def apply_journal_all(opts={})
        limit           = opts[:limit]           || 10
        apply_retry_max = opts[:apply_retry_max] || 10
        DestJournal.query.filter(:apply_failed_count, "<", apply_retry_max).
                          sort(:apply_failed_count, :asc).
                          keys_only.each(:limit=>limit) do |dest_journal_key|
          begin
            apply_journal(dest_journal_key)
          rescue Object => e
            begin
              TinyDS.tx(:force_begin=>true) do
                dest_journal = DestJournal.get(dest_journal_key)
                if dest_journal
                  dest_journal.apply_failed_count += 1
                  dest_journal.save
                end
              end
            rescue TransactionFailed => e
              # ignore
            end
          end
        end
        nil
      end
    end
  end
end
