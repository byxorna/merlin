$:.unshift File.dirname(__FILE__)
require 'etcd'
require 'logger'
require 'merlin/emitter'
require 'merlin/watcher/etcd'
require 'merlin/watcher/file'
require 'merlin/coalescer'

module Merlin ; end
