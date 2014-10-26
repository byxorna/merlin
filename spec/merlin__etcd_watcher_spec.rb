require 'spec_helper'
require 'etcd'
require 'ostruct'

describe Merlin::EtcdWatcher do
  let(:host) { 'localhost' }
  let(:port) { 4001 }
  let(:client) { Etcd::Client.new(:host => host, :port => port) }
  let(:path) {'/merlin/test'}
  let(:watcher) { Merlin::EtcdWatcher.new(client, path) }
  after(:each) { watcher.terminate ; sleep 0.1 }


  context "get" do
    it "yields data" do
      watcher.client.stub(:get).and_return("test_data")
      d = nil
      watcher.get do |data|
        d = data
      end
      expect(d).equal? "test_data"
    end
    it "returns data" do
      watcher.client.stub(:get).and_return("test_data")
      expect(watcher.get).equal? "test_data"
    end
  end

  context "observe" do
    it "requires a block" do
      expect{ watcher.observe }.to raise_error
    end
    it "watches path" do
      etcd_index = 100
      watcher.client.stub(:watch) {
        sleep 0.1 # need this because observe is a tight loop
        OpenStruct.new({
          :etcd_index => etcd_index,
          :action => "update",
          :node => OpenStruct.new({
            :key => File.join(path,"updated"),
            :modified_index => etcd_index += 1
          })
        })
      }
      results = []
      watcher.observe(100) do |val|
        results << val
      end
      sleep 0.3    # accumulate some results
      expect(results.first).not_to eq(nil)
      expect(results.first.etcd_index).to eq(100)
      expect(results.first.node.modified_index).to eq(101)
    end
    it "starts a thread" do
      watcher.client.stub(:watch){ sleep }
      watcher.observe {|v| raise "I should never be run" }
      expect(watcher.instance_variable_get(:@thread).alive?).to eq true
      expect(watcher.running).to eq true
    end
  end

  context "terminate" do
    it "kills thread" do
    watcher.client.stub(:watch){ sleep }
    watcher.observe {|v| raise "I should never be run" }
    watcher.terminate
    expect(watcher.running).to eq false
    sleep 0.1 # give it time to react to the signal
    expect(watcher.instance_variable_get(:@thread).alive?).to eq false
    end
  end

end
