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
  let(:data) do
    OpenStruct.new({
      :children => [
        EtcdNode.new("web1","10.0.0.1:80"),
        EtcdNode.new("web4","10.0.0.4:80"),
        EtcdNode.new("web2","10.0.0.2:80"),
        EtcdNode.new("web3","10.0.0.3:80"),
      ]
    })
  end
  let(:templates) {{
    "spec/templates/a.conf.erb" => "a.conf",
    "spec/templates/b.conf.erb" => "b.conf"
  }}
  let(:statics) {{
    "spec/src/static1.txt" => "static1.txt",
    "spec/src/static2.txt" => "static2.txt"
  }}
  let(:destination) { 'spec/tmp' }
  let(:check_cmd) { nil }
  let(:commit_cmd) { nil }
  let(:test_file) { File.join(destination,"test_file") }
  let(:emitter) { Merlin::Emitter.new('testsuite',templates, destination) }
  let(:static_emitter) { Merlin::Emitter.new('testsuite',templates, destination, :statics => statics) }
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
      emitter.instance_variable_set(:@check_cmd, "touch #{test_file}")
      emitter.emit(data)
      expect(File.read(test_file)).to eq('')
    end
    it "runs commit command" do
      expect{File.read(test_file)}.to raise_error Errno::ENOENT
      emitter.instance_variable_set(:@commit_cmd,"touch #{test_file}")
      emitter.emit(data)
      expect(File.read(test_file)).to eq('')
    end
    it "doesnt run commit if check fails" do
      emitter.instance_variable_set(:@check_cmd, "exit 1").
        instance_variable_set(:@commit_cmd,"touch #{test_file}")
      res = emitter.emit(data)
      expect(res).to eq(false)
      expect{File.read(test_file)}.to raise_error Errno::ENOENT
    end
    it "doesnt run check if no changes to template output" do
      file = File.join(destination, 'test')
      res = emitter.emit(data)
      expect(res).to eq(true)
      emitter.instance_variable_set(:@check_cmd, "touch #{file}")
      res = emitter.emit(data)
      expect(res).to eq(false)  # nothing updated
      expect{File.read(file)}.to raise_error Errno::ENOENT
    end
    it "rolls back template output files if check fails" do
      existing_file = File.join(destination,"a.conf")
      File.open(existing_file,'w') {|f| f.write "original file"}
      emitter.instance_variable_set(:@check_cmd, "exit 1")
      res = emitter.emit(data)
      expect(res).to eq(false)
      expect(File.read(existing_file)).to eq("original file")
    end
    it "rolls back template output files if check command is missing" do
      existing_file = File.join(destination,"a.conf")
      File.open(existing_file,'w') {|f| f.write "original file"}
      emitter.instance_variable_set(:@check_cmd, "sldfjasdifjaosd")
      res = emitter.emit(data)
      expect(res).to eq(false)
      expect(File.read(existing_file)).to eq("original file")
    end
    it "rolls back static output files if check fails" do
      static_outputs = static_emitter.static_map.values
      files = static_outputs.map{|s| Pathname.new(static_emitter.destination).join(s) }
      files.each do |s|
        File.open(s,'w'){|f| f.write "testing"}
      end
      static_emitter.instance_variable_set(:@check_cmd, "exit 1")
      res = static_emitter.emit(data)
      expect(res).to eq(false)
      expect(File.read(files.first)).to eq("testing")
      expect(File.read(files.last)).to eq("testing")
    end
    it "templates commands with dest" do
      tmpdir = Dir.tmpdir
      emitter.instance_variable_set(:@custom_tmp,tmpdir)
      emitter.instance_variable_set(:@check_cmd,"echo '<%= dest %>' > #{test_file}")
      emitter.instance_variable_set(:@commit_cmd,"echo '<%= dest %>' > #{test_file}2")
      emitter.emit(data)
      expect(File.read(test_file)).to match(%r|^#{tmpdir}|)
      expect(File.read("#{test_file}2")).to match(%r|spec/tmp|)
    end
    it "templates commands with files" do
      static_emitter.instance_variable_set(:@check_cmd,'echo "<%= files.sort.join("\n") %>" > ' + test_file)
      static_emitter.emit(data)
      res = File.read(test_file).lines.map(&:strip)
      expect(res[0]).to match(%r|/a.conf$|)
      expect(res[1]).to match(%r|/b.conf$|)
      expect(res[2]).to match(%r|/static1.txt$|)
      expect(res[3]).to match(%r|/static2.txt$|)
      expect(res.length).to eq(4)
    end
    it "missing template command variables raise" do
      emitter.instance_variable_set(:@check_cmd,'<%= missing_var %>')
      expect{emitter.emit(data)}.to raise_error
    end
    it "ruby syntax error in command template raises" do
      emitter.instance_variable_set(:@check_cmd,'<% fuck ruby syntax bruh %>')
      expect{emitter.emit(data)}.to raise_error
    end
  end
end
