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
  let(:static_files) {{
    "spec/src/static1.txt" => "static1.txt",
    "spec/src/static2.txt" => "static2.txt"
  }}
  let(:destination) { 'spec/tmp' }
  let(:check_cmd) { nil }
  let(:commit_cmd) { nil }
  let(:test_file) { File.join(destination,"test_file") }
  let(:emitter) { Merlin::Emitter.new(templates, destination) }
  let(:static_emitter) { Merlin::Emitter.new(templates, destination, :static_files => static_files) }
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
      expect{File.read(test_file)}.to raise_error Errno::ENOENT
      allow(emitter).to receive_messages(:check_cmd => "touch #{test_file}")
      emitter.emit(data)
      expect(File.read(test_file)).to eq('')
    end
    it "runs commit command" do
      expect{File.read(test_file)}.to raise_error Errno::ENOENT
      allow(emitter).to receive_messages(:commit_cmd => "touch #{test_file}")
      emitter.emit(data)
      expect(File.read(test_file)).to eq('')
    end
    it "doesnt run commit if check fails" do
      allow(emitter).to receive_messages(:check_cmd => "exit 1", :commit_cmd => "touch #{test_file}")
      res = emitter.emit(data)
      expect(res).to eq(false)
      expect{File.read(test_file)}.to raise_error Errno::ENOENT
    end
    it "doesnt run check if no changes to template output" do
      file = File.join(destination, 'test')
      res = emitter.emit(data)
      expect(res).to eq(true)
      allow(emitter).to receive_messages(:check_cmd => "touch #{file}")
      res = emitter.emit(data)
      expect(res).to eq(true)
      expect{File.read(file)}.to raise_error Errno::ENOENT
    end
    it "rolls back template output files if check fails" do
      existing_file = File.join(destination,"a.conf")
      File.open(existing_file,'w') {|f| f.write "original file"}
      allow(emitter).to receive_messages(:check_cmd => "exit 1")
      res = emitter.emit(data)
      expect(res).to eq(false)
      expect(File.read(existing_file)).to eq("original file")
    end
    it "rolls back static output files if check fails" do
      static_outputs = static_emitter.static_files.values
      s1,s2 = static_outputs
      static_outputs.each do |s|
        File.open(s,'w'){|f| f.write "testing"}
      end
      allow(static_emitter).to receive_messages(:check_cmd => "exit 1")
      res = static_emitter.emit(data)
      expect(res).to eq(false)
      expect(File.read(s1)).to eq("testing")
      expect(File.read(s2)).to eq("testing")
    end
    it "templates commands with destination" do
      emitter.instance_variable_set(:@check_cmd,"echo '<%= destination %>' > #{test_file}")
      emitter.instance_variable_set(:@commit_cmd,"echo '<%= destination %>' > #{test_file}2")
      emitter.emit(data)
      # because destination is resolved to absolute path, lets just see if it ends in what we expect
      expect(File.read(test_file)).to match(%r|spec/tmp$|)
      expect(File.read("#{test_file}2")).to match(%r|spec/tmp$|)
    end
    it "templates commands with outputs" do
      # set the static_files instance var to avoid readable? checking when stuffing into constructor
      emitter.instance_variable_set(:@static_files,{'/static1' => '/static1','/static2' => '/static2'})
      emitter.instance_variable_set(:@check_cmd,'echo "<%= outputs.sort.join("\n") %>" > ' + test_file)
      emitter.emit(data)
      res = File.read(test_file).lines.map(&:strip)
      expect(res[0]).to match(%r|#{destination}/a.conf$|)
      expect(res[1]).to match(%r|#{destination}/b.conf$|)
      expect(res[2]).to eq('/static1')
      expect(res[3]).to eq('/static2')
      expect(res.length).to eq(4)
    end
    it "templates commands with dynamic_outputs" do
      emitter.instance_variable_set(:@check_cmd,'echo "<%= dynamic_outputs.sort.join("\n") %>" > ' + test_file)
      emitter.emit(data)
      res = File.read(test_file).lines.map(&:strip)
      expect(res[0]).to match(%r|#{destination}/a.conf$|)
      expect(res[1]).to match(%r|#{destination}/b.conf$|)
      expect(res.length).to eq(2)
    end
    it "templates commands with static_outputs" do
      emitter.instance_variable_set(:@static_files,{'/static1' => '/static1','/static2' => '/static2'})
      emitter.instance_variable_set(:@check_cmd,'echo "<%= static_outputs.sort.join("\n") %>" > ' + test_file)
      emitter.emit(data)
      res = File.read(test_file).lines.map(&:strip)
      expect(res[0]).to eq('/static1')
      expect(res[1]).to eq('/static2')
      expect(res.length).to eq(2)
    end
    it "missing template command variables raise" do
      emitter.instance_variable_set(:@check_cmd,'<%= missing_var %>')
      expect{emitter.emit(data)}.to raise_error
      #TODO we should test that other instance vars are NOT available in the binding. they are now
    end
    it "ruby syntax error in command template raises" do
      emitter.instance_variable_set(:@check_cmd,'<%= fuck %>')
      expect{emitter.emit(data)}.to raise_error
    end
  end
end
