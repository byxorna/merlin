require 'merlin'
require 'timers'
require 'merlin/logstub'

# Helper class to coalesce events triggered within a window
# Will cache events that happen with a timeout, and once the timer
# expires, will yield the last event to the block provided
#
# Example:
#
# window = 60
# coalescer = Coalescer.new window do |data|
#   puts "finally got #{data} after #{window} seconds"
# end
# etcd.observe do |data|
#   # will only fire after 60s delays with the most recent value
#   coalescer.coalesce data
# end

module Merlin
  class Coalescer
    include Logstub

    def initialize timeout = 1, logger = nil, &block
      raise "You need to give me a block" unless block_given?
      @logger = logger
      @timeout = timeout
      @data = nil
      @timers = Timers::Group.new
      @block = block
    end

    def coalesce data
      @data = data
      if @timers.empty?
        logger.debug "Received data outside window, scheduling new timer"
        @timers.after(@timeout) do
          logger.debug "Yielding #{@data} after #{@timeout} seconds"
          @block.call(@data) unless @block.nil?
        end
      else
        logger.debug "Received new data within update window"
      end
    end

    def fire
      # just delegate fire to trigger all timers that are ready
      @timers.fire
    end

  end
end
