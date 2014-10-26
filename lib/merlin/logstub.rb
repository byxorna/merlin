require 'merlin'
module Merlin
  module Logstub
    def method_missing(method_sym, *arguments, &block)
      if [:debug,:info,:warn,:error,:fatal].include? method_sym
        # just stub out common logger methods
        nil
      else
        super
      end
    end
    def logger
      @logger.nil? ? self : @logger
    end
  end
end
