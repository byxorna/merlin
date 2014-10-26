require 'spec_helper'
require 'fileutils'

describe Merlin::FileWatcher do
  let(:path) { 'spec/tmp' }
  let(:filename) { File.join(path, 'file_watcher.test') }
  let(:watcher) { Merlin::FileWatcher.new(filename) }
  after(:each) do
    watcher.stop
    File.unlink(*Dir.glob(File.join(path,'*')))
  end

  context "observe" do
    it "watches a file" do
      modified = false
      watcher.observe do |f|
        puts f.inspect
        modified = true
      end
      expect{File.read(filename)}.to raise_error Errno::ENOENT
      FileUtils.touch(filename)

      sleep 1 # give it time if its in polling mode
      watcher.stop
      expect(modified).to eq(true)
    end
    it "ignores other files" do
      modified = false
      watcher.observe do |f|
        modified = true
      end
      FileUtils.touch(File.join(path,'different_file'))
      sleep 1 # give it time if its in polling mode
      watcher.stop
      expect(modified).to be false
    end
  end
end
