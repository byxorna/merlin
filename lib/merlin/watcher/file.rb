require 'merlin'
require 'digest'
require 'listen'

#https://github.com/guard/listen
module Merlin
  class FileWatcher
    attr_accessor :filename
    def initialize name, filename
      @name, @filename = name, filename
    end

    def observe &block
      #TODO listen to a directory, yield block whenever there is a change
      @listener = Listen.to(File.dirname(filename), :only => %r|#{filename}$|) do |mod,add,del|
        # run the block if the file was modified
        yield block, mod unless mod.nil?
      end
      @listener.start
#Digest::SHA256.hexdigest File.read "data.dat"
    end

    # pass all unknown methods through to the listener
    # so humans can call #start #stop #pause #unpause #processing? etc.
    def method_missing(meth, *args, &block)
      @listener.send(meth, *args, &block)
    end

  end
end

