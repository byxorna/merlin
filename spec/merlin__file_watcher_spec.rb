require 'spec_helper'
require 'fileutils'
# TODO this is super shitty to have these sleeps sprinkled around.
# Need to figure out a good way to handle the concurrency of this Listener module

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
      File.open(filename,'w'){|f| f.write 'contents'}
      watcher.observe {|f| modified = true }
      expect(watcher.processing?).to eq(true)
      sleep 1
      FileUtils.touch(filename)
      sleep 1 # give it time if Listen is in polling mode
      expect(modified).to eq(true)
    end
    it "ignores other files" do
      modified = false
      watcher.observe {|f| modified = true }
      FileUtils.touch(File.join(path,'different_file'))
      sleep 1 # give it time if its in polling mode
      expect(modified).to be false
    end
  end
end
