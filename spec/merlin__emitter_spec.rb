require 'spec_helper'
require 'ostruct'
require 'logger'

class EtcdNode
  attr_accessor :key, :value
  def initialize(k,v)
    @key, @value = k,v
  end
end
describe Merlin::Emitter do
  let(:data) {
    OpenStruct.new({
      :children => [
        EtcdNode.new("web1","10.0.0.1:80"),
        EtcdNode.new("web4","10.0.0.4:80"),
        EtcdNode.new("web2","10.0.0.2:80"),
        EtcdNode.new("web3","10.0.0.3:80"),
      ]
    })
  }
  let(:templates) {{
    "spec/templates/a.conf.erb" => "a.conf",
    "spec/templates/b.conf.erb" => "b.conf"
  }}
  let(:destination) { 'spec/tmp' }
  let(:check_cmd) { nil }
  let(:commit_cmd) { nil }
  let(:emitter) { Merlin::Emitter.new(templates, destination) }
  after(:each) do
    # delete everything in spec/tmp/
    File.unlink(*Dir.glob(File.join(destination,'*')))
  end

  context "emit(data)" do
    it "writes multiple templates" do
      res = emitter.emit(data)
      a = File.read(File.join(destination,'a.conf'))
      b = File.read(File.join(destination,'a.conf'))
      expect(Digest::SHA256.hexdigest(a)).to eq('b1af466c9f106e678527885f0423218cb492ab4c643f36672b6a28946dfb6bef')
      expect(a).to eq(b)
      expect(res).to eq(true)
    end
    it "runs check command" do
      test_file = File.join(destination,"test")
      expect{File.read(test_file)}.to raise_error Errno::ENOENT
      allow(emitter).to receive_messages(:check_cmd => "touch #{test_file}")
      emitter.emit(data)
      expect(File.read(test_file)).to eq('')
    end
    it "runs commit command" do
      test_file = File.join(destination,"commit_success")
      expect{File.read(test_file)}.to raise_error Errno::ENOENT
      allow(emitter).to receive_messages(:commit_cmd => "touch #{test_file}")
      emitter.emit(data)
      expect(File.read(test_file)).to eq('')
    end
    it "doesnt run commit if check fails" do
      test_file = File.join(destination,"shouldnt_exist")
      allow(emitter).to receive_messages(:check_cmd => "exit 1", :commit_cmd => "touch #{test_file}")
      res = emitter.emit(data)
      expect(res).to eq(false)
      expect{File.read(test_file)}.to raise_error Errno::ENOENT
    end
    it "doesnt run check if no changes to output" do
      file = File.join(destination, 'test')
      res = emitter.emit(data)
      expect(res).to eq(true)
      allow(emitter).to receive_messages(:check_cmd => "touch #{file}")
      res = emitter.emit(data)
      expect(res).to eq(true)
      expect{File.read(file)}.to raise_error Errno::ENOENT
    end
    it "replaces files if check fails" do
      existing_file = File.join(destination,"a.conf")
      File.open(existing_file,'w') {|f| f.write "original file"}
      allow(emitter).to receive_messages(:check_cmd => "exit 1")
      res = emitter.emit(data)
      expect(res).to eq(false)
      expect(File.read(existing_file)).to eq("original file")
    end
  end
end
