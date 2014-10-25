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

    # this will persistently observe the path from wait_index and run block
    # for each change detected. The quirk is that we will rewatch for the 
    # etcd_index+1 index, so if multiple changes happen between watches, we
    # fire for each one. TODO we should add debouncing so we can defer updates
    # within a window
    def observe wait_index = nil, &block
      raise "You should give me a block" unless block_given?
      running = true
      index = wait_index
      @thread = Thread.start do
        logger.debug "Watching #{path} with index #{index.inspect}"
        while running
          val = client.watch(path, recursive: true, index: index)
          if running
            logger.info "Watch fired for #{path}: #{val.action} #{val.node.key} with etcd index #{val.etcd_index}"
            # lets watch for the next event
            index = val.etcd_index + 1
            block.call(val)
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

    def rerun wait_index = nil, &block
      logger.debug "rerun for #{path}"
      @thread.terminate if @thread.alive?
      logger.debug "after termination for #{path}"
      observe wait_index, block
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

