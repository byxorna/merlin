require 'merlin'
require 'listen'
require 'logger'
require 'merlin/logstub'

module Merlin
  class FileWatcher
    include Logstub # provide stubbed logger methods

    attr_accessor :filename, :listener
    def initialize filename, logger = nil
      @filename = filename
      @logger = logger
      @listener = nil
    end

    def observe &block
      raise "You should give me a block" unless block_given?
      #TODO listen to a directory, yield block whenever there is a change
      logger.debug "Watching for changes to #{filename}"
      @listener = Listen.to(File.dirname(filename), :only => %r|#{File.basename filename}|) do |mod,add,del|
        # run the block if the file was modified
        unless mod.empty?
          logger.debug "Static files changed: #{mod.inspect}"
          yield mod
        end
      end
      logger.debug "Starting listener"
      @listener.start
      self
    end

    # pass all unknown methods through to the listener
    # so humans can call #start #stop #pause #unpause #processing? etc.
    def method_missing(meth, *args, &block)
      if [:start, :stop, :pause, :unpause, :processing?].include? meth
        return listener.send(meth, *args, &block) unless listener.nil?
      end
      super
    end

  end
end

