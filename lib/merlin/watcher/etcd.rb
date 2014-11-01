require 'merlin'
require 'logger'
require 'merlin/logstub'

module Merlin
  class EtcdWatcher
    include Logstub
    attr_reader :running, :index, :path, :client

    def initialize client, path, opts={}
      @path = path
      @client = client
      @running = false
      @logger = opts[:logger]
    end

    def get
      logger.debug "Getting #{path} from #{client.host}:#{client.port}"
      begin
        data = client.get(path, :recursive => true, :sorted => true)
      rescue => e
        logger.error "Unable to get #{path} from etcd: #{e.message}"
        raise
      end
      if block_given?
        yield data
      else
        return data
      end
    end

    # this will persistently observe the path from wait_index and run block
    # for each change detected. The quirk is that we will rewatch for the 
    # modified_index+1 index, so if multiple changes happen between watches, we
    # fire for each one. TODO we should add debouncing so we can defer updates
    # within a window
    def observe wait_index = nil
      raise "You should give me a block" unless block_given?
      @running = true
      index = wait_index
      @thread = Thread.start do
        logger.debug "Started etcd watch thread at #{path} with index #{index.inspect}"
        while running
          logger.debug "Awaiting index #{index} at #{path}"
          val = client.watch(path, recursive: true, index: index)
          if running
            logger.info "Watch fired for #{path}: #{val.action} #{val.node.key} with etcd index #{val.etcd_index} and modified index #{val.node.modified_index}"
            # lets watch for the next event from modified index
            index = val.node.modified_index + 1
            yield val
          end
        end
      end
      self
    end

    def terminate
      unless @thread.nil?
        @running = false
        @thread.terminate if @thread.alive?
      end
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

