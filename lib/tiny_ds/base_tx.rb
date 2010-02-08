# memo デプロイ時に未完了のトランザクションがあってトランザクション定義がかわったら？version???
module TinyDS
  class BaseTx
    class SrcJournal < ::TinyDS::Base
      property :dest_klass,         :string, :index=>false
      property :dest_key,           :string, :index=>false
      property :method_name,        :string, :index=>false
      property :args_yaml,          :text
      property :status,             :string # created => copied
      property :copy_failed_count,  :integer, :default=>0
      property :updated_at,         :time
      property :created_at,         :time

      def self.kind; "__SrcJournal" end
      def key_string
        self.key.to_s
      end

      def self.create_journal(src, dest, method_name, *args)
        # TODO raise if current_tx is none
        TinyDS.tx(:force_begin=>false) do
          SrcJournal.create({
                       :dest_klass  => dest.class.name,
                       :dest_key    => dest.key.to_s,
                       :method_name => method_name.to_s,
                       :args_yaml   => args.to_yaml,
                       :status      => "created"
                      }, :parent=>src)
        end
      end

      # src_journalからdest_journalにコピーする
      def copy_to_dest_journal
        src_journal = self
        dest_journal = nil

        TinyDS.tx(:retries=>10, :force_begin=>true){ # EG-B
          dest_journal = DestJournal.get_by_name(src_journal.key_string, src_journal.dest_key)
          unless dest_journal
            dest_journal = DestJournal.create({
              :dest_klass  => src_journal.dest_klass,
              :method_name => src_journal.method_name,
              :args_yaml   => src_journal.args_yaml,
              :status      => "copied"
             },
            { :parent => src_journal.dest_key,
              :name   => src_journal.key_string
             })
          end
        }

        # (dest_journalができたら)src_journalをstatus="copied"に
        src_journal.tx_update{|sj|
          if sj.status=="created"
            sj.status = "copied"
          end
        }

        return dest_journal.key
      rescue Object => e
        increment_copy_failed_count
        throw e
      end

      def increment_copy_failed_count
        self.tx_update{|sj|
          sj.copy_failed_count += 1
        }
      rescue AppEngine::Datastore::TransactionFailed => e
        # ignore
      end
    end

    class DestJournal < ::TinyDS::Base
      property :dest_klass,         :string, :index=>false
      property :method_name,        :string, :index=>false
      property :args_yaml,          :text
      property :status,             :string # copied => done
      property :apply_failed_count, :integer, :default=>0
      property :updated_at,         :time
      property :created_at,         :time

      def self.kind; "__DestJournal" end

      # destの'method_name'を実行し、dest_journalをstatus="done"にする
      def self.apply_journal(dest_journal_key)
        TinyDS.tx(:retries=>10, :force_begin=>true){ # EG-B
          dest_journal = DestJournal.get(dest_journal_key)
          return if dest_journal.status=="done"
          klass = const_get(dest_journal.dest_klass)
          dest = klass.get(dest_journal.parent_key)
          # TODO if dest.nil? ...
          dest.send(dest_journal.method_name, *(YAML.load(dest_journal.args_yaml)))
          dest_journal.status = "done"
          dest_journal.save
        }
        nil
      rescue Object => e
        increment_apply_failed_count(dest_journal_key)
        raise e
      end

      def self.increment_apply_failed_count(dest_journal_key)
        TinyDS.tx(:force_begin=>true) do
          dest_journal = DestJournal.get(dest_journal_key)
          if dest_journal
            dest_journal.apply_failed_count += 1
            dest_journal.save
          end
        end
      rescue AppEngine::Datastore::TransactionFailed => e
        # ignore
      end
    end

    class << self
      #=============================================================================================
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
        SrcJournal.create_journal(src, dest, method_name, *args)
      end

      #=============================================================================================
      # (STEP2) copy_journal
      # create dest_journal as child of dest.
      # dest_journalができてsrc_journal.status=="copied"になるまで(cronなどで)繰り返し実行する
      # usage:
      #   dest_journal_key = src_journal.copy_to_dest_journal

      #=============================================================================================
      # (STEP3) apply_journal
      #  dest_journal.status=="done" になるまで繰り返し実行する
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

      # src_journalsをcopy/applyする
      # usage:
      #   until src_journals.empty?
      #     src_journals = TinyDS::BaseTx.apply(src_journals)
      #   end
      def apply(src_journals)
        unless src_journals.kind_of?(Array)
          src_journals = [src_journals]
        end
        failed_src_journals = []
        src_journals.each do |sj|
          begin
            djk = sj.copy_to_dest_journal
            DestJournal.apply_journal(djk)
          rescue Object => e
            failed_src_journals << sj
          end
        end
        failed_src_journals
      end

      def rollforward
        rollforward_copy + rollforward_apply
      end

      # 実行されていないcopy_journalの実行
      def rollforward_copy(opts={})
        limit          = opts[:limit]          || 10
        copy_retry_max = opts[:copy_retry_max] || 10
        q = SrcJournal.query.filter(:status=>"created").
                             filter(:copy_failed_count, "<", copy_retry_max)
        q.sort(:copy_failed_count, :asc).each(:limit=>limit) do |src_journal|
          src_journal.copy_to_dest_journal
        end
        q.count
      end

      # 実行されていないapply_journalの実行
      def rollforward_apply(opts={})
        limit           = opts[:limit]           || 10
        apply_retry_max = opts[:apply_retry_max] || 10
        q = DestJournal.query.filter(:status=>"copied").
                              filter(:apply_failed_count, "<", apply_retry_max)
        q.sort(:apply_failed_count, :asc).keys_only.each(:limit=>limit) do |dest_journal|
          DestJournal.apply_journal(dest_journal.key)
        end
        q.count
      end
    end
  end
end
