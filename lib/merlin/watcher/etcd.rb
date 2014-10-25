require 'merlin'
require 'logger'

module Merlin
  class EtcdWatcher
    attr_accessor :name, :client, :logger, :path, :index, :running
    def initialize(name,client,path)
      @name = "watcher::#{name}"
      @path = path
      @client = client
      @running = false
      @logger = Logger.new STDOUT
    end

    # run a block ever time we observe a change at path
    # and parameterize it with the full contents of what is available at that path
    #def observe &block
    #  raise "You should give me a block" unless block_given?
    #  logger.info "Watching #{path} for changes"
    #  etcd.observe(path) do |k,v,info|
    #    logger.debug "Saw an update at #{k}: #{v} #{info.inspect}"
    #    # TODO should we be querying for the waitIndex instead of latest??
    #    get path, &block
    #  end
    #end

    def get &block
      logger.debug "Getting #{path}"
      begin
        data = client.get(path, :recursive => true, :sorted => true)
        if block_given?
          yield data
        else
          return data
        end
      rescue => e
        logger.error "Unable to get #{path} from etcd"
        raise e
      end
    end

    def observe &block
      raise "You should give me a block" unless block_given?
      running = true
      index = nil
      @thread = Thread.start do
        logger.debug "Watching #{path} with index #{index.inspect}"
        while running
          val = client.watch(path, recursive: true, index: index)
          if running
            logger.info "Watch fired for #{path}: #{val.action} #{val.node.key} with modified index #{val.node.modified_index}"
            index = val.node.modified_index + 1
            block.call(val.node)
          end
        end
      end
      self
    end

    def terminate
      running = false
      @thread.terminate if @thread.alive?
      self
    end

    def rerun &block
      logger.debug "rerun for #{path}"
      @thread.terminate if @thread.alive?
      logger.debug "after termination for #{path}"
      observe block
    end

    def join
      @thread.join
      self
    end

    def status
      @thread.status
    end

    def pp_status
      "#{path}: #{pp_thread_status}"
    end

    def pp_thread_status
      st = @thread.status
      st = 'dead by exception'   if st == nil
      st = 'dead by termination' if st == false
      st
    end
  end
end

