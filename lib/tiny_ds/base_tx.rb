module TinyDS
  class BaseTx
    class SrcJournal < ::TinyDS::Base
      property :dest_class,         :string, :index=>false
      property :dest_key,           :string, :index=>false
      property :method_name,        :string, :index=>false
      property :args_yaml,          :text
      property :status,             :string # "created" => "done" (too many fail => "error"???)
      property :failed_count,       :integer, :default=>0
      property :is_created_src_key, :string # set src_key  if status is "created"
      property :is_created_dest_key,:string # set dest_key if status is "created"
      property :updated_at,         :time
      property :created_at,         :time

      def self.kind; "__SrcJournal2" end
      def key_string
        self.key.to_s
      end

      # Build src_journal of "src to dest BASE-transaction".
      # src_journal is child of src.
      # TODO :class_method=>true option. dest_key==nil and set dest_journal_key.
      def self.build_journal(src, dest, method_name, *args)
        if dest.kind_of?(TinyDS::Base)
          dest = {:class=>dest.class.name, :key=>dest.key}
        end
        sj = SrcJournal.new({
                    :dest_class  => dest[:class],
                    :dest_key    => dest[:key].to_s,
                    :method_name => method_name.to_s,
                    :args_yaml   => args.to_yaml,
                    :status      => "created"
                   }, :parent=>src)
        sj.set_is_created_keys
        return sj
      end

      def dest_journal_key
        DestJournal.build_key(self.key_string, self.dest_key)
      end

      def args
        YAML.load(self.args_yaml)
      end

      def tx_set_done(retries)
        self.tx(:retries=>retries, :force_begin=>true){|sj|
          if sj.status=="created"
            sj.status = "done"
            sj.set_is_created_keys
            sj.save
          end
        }
      end

      def tx_increment_failed_count(retries)
        self.tx(:retries=>retries, :force_begin=>true){|sj|
          sj.failed_count += 1
          sj.save
        }
      end

      def set_is_created_keys
        if self.status=="created"
          self.is_created_src_key  = self.parent_key.to_s
          self.is_created_dest_key = self.dest_key
        else
          self.is_created_src_key  = nil
          self.is_created_dest_key = nil
        end
      end

      def self.query_created_by_src_key(k)
        k = k.to_s if k.kind_of?(AppEngine::Datastore::Key)
        self.query.filter(:is_created_src_key=>k)
      end

      def self.query_created_by_dest_key(k)
        k = k.to_s if k.kind_of?(AppEngine::Datastore::Key)
        self.query.filter(:is_created_dest_key=>k)
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
      def apply(src_journal_or_key, opts={})
        retries = opts[:retries] || 10

        src_journal = if src_journal_or_key.kind_of?(SrcJournal)
                        src_journal_or_key
                      else
                        SrcJournal.get(src_journal_or_key) # get without tx
                      end
        if src_journal.nil?
          raise "src_journal is nil. src_journal_or_key=#{src_journal_or_key}"
        end
        if src_journal.status == "done"
          return nil
        end

# retries = 0
        TinyDS.tx(:retries=>retries, :force_begin=>true){
# $app_logger.info "BaseTx.apply src=[#{src_journal_key.inspect}] dest=[#{src_journal.dest_journal_key.inspect}] retries=#{retries}"
# retries += 1

          dest_journal, dest = TinyDS.batch_get([
            [src_journal.dest_journal_key, DestJournal],
            [src_journal.dest_key,         src_journal.dest_class]
          ])

# $app_logger.info "BaseTx.apply dest_journal.nil?=#{dest_journal.nil?}"
          if dest_journal.nil?
            # TODO if dest.nil? ...
            entities_to_put = dest.send(src_journal.method_name, *(src_journal.args)).to_a
            entities_to_put << DestJournal.new({}, :key=>src_journal.dest_journal_key)
            TinyDS.batch_save(entities_to_put)
          end
        }

        # If you want return faster, set_done needs about 100ms, skip it.
        # (and you may need to run apply_pendings in cron or TQ to set_done)
        # MEMO async put may be good for this.
        unless opts[:skip_set_done]
          src_journal.tx_set_done(retries)
        end
        nil
      rescue => e
# $app_logger.info "BaseTx.apply e=#{e.inspect}"
        begin
          src_journal.tx_increment_failed_count
        rescue => e2
          # ignore
        end
        raise e
      end

      # apply pending journals
      def apply_pendings(opts={})
        limit           = opts[:limit]           || 10
        apply_retry_max = opts[:apply_retry_max] || 10
        q = SrcJournal.query.filter(:status=>"created").
                             filter(:failed_count, "<", apply_retry_max)
        q.sort(:failed_count, :asc).each(:limit=>limit) do |src_journal|
          TinyDS::BaseTx.apply(src_journal)
        end
        nil
      end
    end
  end
end
