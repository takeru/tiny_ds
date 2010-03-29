module TinyDS
  class BaseTx
    class SrcJournal < ::TinyDS::Base
      property :dest_class,         :string, :index=>false
      property :dest_key,           :string
      property :method_name,        :string, :index=>false
      property :args_yaml,          :text
      property :status,             :string # "created" => "done"
      property :failed_count,       :integer, :default=>0
      property :updated_at,         :time
      property :created_at,         :time

      def self.kind; "__SrcJournal2" end
      def key_string
        self.key.to_s
      end

      # Build src_journal of "src to dest BASE-transaction".
      # src_journal is child of src.
      def self.build_journal(src, dest, method_name, *args)
        if dest.kind_of?(TinyDS::Base)
          dest = {:class=>dest.class.name, :key=>dest.key}
        end
        SrcJournal.new({
                    :dest_class  => dest[:class],
                    :dest_key    => dest[:key].to_s,
                    :method_name => method_name.to_s,
                    :args_yaml   => args.to_yaml,
                    :status      => "created"
                   }, :parent=>src)
      end

      def dest_journal_key
        DestJournal.build_key(self.key_string, self.dest_key)
      end

      def args
        YAML.load(self.args_yaml)
      end
    end

    # If exist, apply is done.
    # parent is dest, name is src_journal.key_string
    class DestJournal < ::TinyDS::Base
      property :created_at,         :time
      def self.kind; "__DestJournal2" end
    end

    class << self
      #=============================================================================================
      # (STEP1) build_journal
      #
      # build src_journal as child of src.
      #
      # usage:
      #   dest = ExampleDestKlass.get("...")
      #   TinyDS.tx do # EG-A
      #     src     = Ent.get(...)
      #     journal = TinyDS::BaseTx.build_journal(
      #       src,  # entity of EG-A
      #       dest, # or {:class=>"ExampleDestKlass", :key=>dest.key} entity of EG-B
      #       :apply_some,
      #       arg1, arg2, arg3, ...
      #     )
      #     TinyDS.batch_save([src, journal])
      #   end
      #
      #   TODO add entityA1.base_call(dest, method, arg1, arg2, ...)
      #
      def build_journal(src, dest, method_name, *args)
        SrcJournal.build_journal(src, dest, method_name, *args)
      end

      #=============================================================================================
      # (STEP2) apply
      #
      # apply src_journal.
      #
      # usage:
      #   src_journal_key = "..."
      #   TinyDS::BaseTx.apply(src_journal_key)
      #
      # class ExampleDestKlass
      #   def apply_some(arg1,arg2,arg3,arg4,...)
      #     self.aaa += arg1
      #     self.bbb += arg2
      #     self.ccc += arg3
      #
      #     entX = Ent.get(arg4)
      #     entX.ddd += arg5
      #
      #     [self, entX]
      #   end
      # end
      #
      # If apply_some returns instance of TinyDS::Base (or array of that),
      # they will be saved with dest_journal for reduce RPC calls.
      #
      def apply(src_journal_key, opts={})
        retries = opts[:retries] || 10

        src_journal = SrcJournal.get(src_journal_key) # get without tx
        if src_journal.nil?
          raise "src_journal is nil. src_journal_key=#{src_journal_key}"
        end
        if src_journal.status == "done"
          return nil
        end

# retries = 0
        TinyDS.tx(:retries=>retries, :force_begin=>true){
# $app_logger.info "BaseTx.apply src=[#{src_journal_key.inspect}] dest=[#{src_journal.dest_journal_key.inspect}] retries=#{retries}"
# retries += 1
          dest_journal = DestJournal.get(src_journal.dest_journal_key)
# $app_logger.info "BaseTx.apply dest_journal.nil?=#{dest_journal.nil?}"
          if dest_journal.nil?
            klass = const_get(src_journal.dest_class)
            dest = klass.get(src_journal.dest_key)
            # TODO if dest.nil? ...
            entities_to_put = dest.send(src_journal.method_name, *(src_journal.args)).to_a
            entities_to_put << DestJournal.new({}, :key=>src_journal.dest_journal_key)
            TinyDS.batch_save(entities_to_put)
          end
        }

        src_journal.tx(:retries=>retries, :force_begin=>true){|sj|
          sj.status = "done"
          sj.save
        }
        nil
      rescue => e
# $app_logger.info "BaseTx.apply e=#{e.inspect}"
        begin
          src_journal.tx(:retries=>retries, :force_begin=>true){|sj|
            sj.failed_count += 1
            sj.save
          }
        rescue => e2
          # ignore
        end
        raise e
      end

      # 実行されていないapplyの実行
      def apply_pendings(opts={})
        limit           = opts[:limit]           || 10
        apply_retry_max = opts[:apply_retry_max] || 10
        q = SrcJournal.query.filter(:status=>"created").
                             filter(:failed_count, "<", apply_retry_max)
        q.sort(:failed_count, :asc).keys_only.each(:limit=>limit) do |src_journal|
          TinyDS::BaseTx.apply(src_journal.key)
        end
        nil
      end

      def root_key(key) # AppEngine::Datastore::Key
        loop do
          k = key.parent
          return key if k.nil?
          key = k
        end
      end
    end
  end
end
