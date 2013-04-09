module Forklift
  class ParallelQuery

    def initialize(args, threads=1, logger)
      @args = args
      @threads = threads
      @logger = logger
    end

    def args
      @args
    end

    def threads
      @threads
    end

    def logger
      @logger
    end

    def active_threads
      @active_threads ||= []
    end

    def count_running_threads
      running_threads = 0
      active_threads.each do |thread|
        running_threads = running_threads + 1 if thread.alive?
      end
      return running_threads
    end

    def collect_running_threads
      active_threads.each do |thread|
        thread.join
      end
    end

    def run_in_thread(query)
      thread = Thread.new {
        begin
          start_time = Time.new
          id = Thread.current.object_id
          thread_db_connection = Mysql2::Client.new(args);
          logger.debug "  > (thread #{id}) #{query}"
          thread_db_connection.query(query)
          thread_db_connection.close
          logger.debug " ... (thread #{id}) took #{Time.new - start_time}s" 
        rescue Exception => e
          logger.log "MYSQL ERROR: mysql command failed: #{e}"
          Thread.main.raise message
        end
      }
      active_threads.push thread
    end

    def run(queries)
      while queries.length > 0
        if count_running_threads < threads
          run_in_thread queries.shift
          sleep(0.1)
        else
          sleep 1
        end
      end
      collect_running_threads
    end

  end
end