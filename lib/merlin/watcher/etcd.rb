require 'merlin'
require 'logger'

module Merlin
  class EtcdWatcher
    attr_accessor :name, :client, :logger
    def initialize(name,etcd_client)
      @name = "watcher::#{name}"
      @client = etcd_client
      @logger = Logger.new STDOUT
    end

    # run a block ever time we observe a change at path
    # and parameterize it with the full contents of what is available at that path
    def observe path, &block
      raise "You should give me a block" unless block_given?
      logger.info "Watching #{path} for changes"
      etcd.observe(path) do |k,v,info|
        logger.debug "Saw an update at #{k}: #{v} #{info.inspect}"
        # TODO should we be querying for the waitIndex instead of latest??
        get path, &block
      end
    end

    def get path, &block
      logger.debug "Getting #{path}"
      begin
        data = client.get(path)
        if block_given?
          yield block, data
        else
          return data
        end
      rescue => e
        logger.error "Unable to get #{path} from etcd"
        raise e
      end
    end

  end
end
