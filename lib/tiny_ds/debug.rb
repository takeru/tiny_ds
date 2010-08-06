module TinyDS
  class Debug
    def self.each_src_journals(src_parent, opts={})
      limit = opts[:limit] || 500

      key_last = src_parent.key
      key_end  = AppEngine::Datastore::Key.from_path(src_parent.key, "~", "~")
      loop do
        q = TinyDS::BaseTx::SrcJournal.query.filter(:__key__, ">", key_last).
                                             filter(:__key__, "<", key_end)
        sjs = q.all(:limit=>limit)
        break if sjs.empty?
        sjs.each do |sj|
          dest_key = AppEngine::Datastore::Key.new(sj.dest_key)
          yield(sj)
          key_last = sj.key
        end
      end
      nil
    end

    # TODO Queries for SrcJournal debug
    #   SrcJournal.query.filter(:created_at, ">", t1).filter(:created_at, "<", t2)
    #                    sort(:created_at, :asc)
    #
    #   SrcJournal.query.filter(:src_parent => src_parent).
    #                    filter(:created_at, ">", t1).filter(:created_at, "<", t2)
    #                    sort(:created_at, :asc)
    #
    #   SrcJournal.query.filter(:src_parent  => src_parent).
    #                    filter(:dest_parent => dest_parent),
    #                    filter(:created_at, ">", t1).filter(:created_at, "<", t2)
    #                    sort(:created_at, :asc)
    #
    # TODO Queries for DestJournal debug
    #   ....

    def self.debug_src_journals(src_parent, opts={})
      sjs = []
      each_src_journals(src_parent, opts) do |sj|
        sjs << sj
      end
      sjs = sjs.sort_by{|sj| sj.created_at }
      djs = TinyDS::BaseTx::DestJournal.get_by_keys(sjs.collect{|sj| sj.dest_journal_key})

      index = 0
      sjs.zip(djs) do |sj,dj|
        dest_parent_key = AppEngine::Datastore::Key.new(sj.dest_key)
        puts "[#{index}] " + ("="*80)
        index += 1
        puts "  method_name = #{sj.method_name}"
        puts "    sj.key           = #{sj.key.inspect}"
        puts "    dest_key         = #{dest_parent_key.inspect}"
        puts "    dest_journal_key = #{sj.dest_journal_key.inspect}"
        puts "    args_yaml        = "
        sj.args_yaml.each do |line|
          puts "    |#{line}"
        end
        puts "  sj.created_at = #{sj.created_at.jst}"
        if true
          if dj
            puts "  dj.created_at = #{dj.created_at.jst} +#{dj.created_at-sj.created_at}sec."
          else
            puts "  dj.created_at = (dj is nil)"
          end
        end
        puts "  sj.updated_at = #{sj.updated_at.jst} +#{sj.updated_at-sj.created_at}sec."
        puts "  status        = #{sj.status} failed_count=#{sj.failed_count}"
        puts ""
      end
      nil
    end
  end
end
