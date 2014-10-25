require 'merlin'
require 'listen'
require 'logger'

module Merlin
  class FileWatcher
    attr_accessor :filename, :logger
    def initialize filename
      @filename = filename
      @logger = Logger.new STDOUT
    end

    def observe &block
      #TODO listen to a directory, yield block whenever there is a change
      logger.debug "Watching for changes to #{filename}"
      @listener = Listen.to(File.dirname(filename), :only => %r|#{File.basename filename}|) do |mod,add,del|
      #@listener = Listen.to(File.dirname(filename)) do |mod,add,del|
        unless mod.empty?
          logger.debug "Static files changed: #{mod.inspect}"
          # run the block if the file was modified
          block.call(mod) unless mod.empty?
        end
      end
      logger.debug "Starting listener"
      @listener.start
      self
    end

    # pass all unknown methods through to the listener
    # so humans can call #start #stop #pause #unpause #processing? etc.
    def method_missing(meth, *args, &block)
      @listener.send(meth, *args, &block)
    end

  end
end

